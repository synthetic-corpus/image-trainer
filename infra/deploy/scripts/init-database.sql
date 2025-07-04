-- Database initialization script for image-trainer application
-- Creates the images table with automatic hash generation

-- Create the images table
CREATE TABLE IF NOT EXISTS images (
    id SERIAL PRIMARY KEY,
    file_name VARCHAR(255) UNIQUE NOT NULL,
    is_masc_human BOOLEAN,
    is_masc_prediction BOOLEAN,
    hash VARCHAR(255) NOT NULL
);

-- Create function to extract hash from filename (only if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_proc WHERE proname = 'extract_hash_from_filename'
    ) THEN
        CREATE FUNCTION extract_hash_from_filename()
        RETURNS TRIGGER AS $$
        BEGIN
            -- Extract filename without extension
            -- Handles cases like "file.jpg", "file.jpeg", "file.png", etc.
            NEW.hash = split_part(NEW.file_name, '.', 1);
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        RAISE NOTICE '✓ Created extract_hash_from_filename function';
    ELSE
        RAISE NOTICE '✓ Function extract_hash_from_filename already exists';
    END IF;
END $$;

-- Create trigger to automatically populate hash column (only if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_trigger WHERE tgname = 'auto_hash_trigger'
    ) THEN
        CREATE TRIGGER auto_hash_trigger
            BEFORE INSERT OR UPDATE ON images
            FOR EACH ROW
            EXECUTE FUNCTION extract_hash_from_filename();
        RAISE NOTICE '✓ Created auto_hash_trigger';
    ELSE
        RAISE NOTICE '✓ Trigger auto_hash_trigger already exists';
    END IF;
END $$;

-- Verify table creation
DO $$
BEGIN
    -- Check if table exists
    IF EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'images'
    ) THEN
        RAISE NOTICE '✓ Images table created successfully';
    ELSE
        RAISE EXCEPTION '✗ Images table creation failed';
    END IF;
    
    -- Check if trigger exists
    IF EXISTS (
        SELECT FROM information_schema.triggers 
        WHERE event_object_table = 'images' AND trigger_name = 'auto_hash_trigger'
    ) THEN
        RAISE NOTICE '✓ Auto-hash trigger created successfully';
    ELSE
        RAISE EXCEPTION '✗ Auto-hash trigger creation failed';
    END IF;
    
    RAISE NOTICE '✓ Database initialization completed successfully!';
END $$; 