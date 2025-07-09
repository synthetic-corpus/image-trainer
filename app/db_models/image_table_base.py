"""
Image model using SQLAlchemy reflection to connect to the images table.
This model automatically reflects the database schema
without manual column declarations.
"""

from sqlalchemy import Column, Integer, String, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import func
from sqlalchemy.orm import session

# This will be initialized in the main app
Base = declarative_base()


class Image_table_base(Base):
    """
    Image model that reflects the 'images' table from the database.

    Reflected columns:
    - id: SERIAL PRIMARY KEY
    - file_name: VARCHAR(255) UNIQUE NOT NULL
    - is_masc_human: BOOLEAN (nullable)
    - is_masc_prediction: BOOLEAN (nullable)
    - hash: VARCHAR(255) NOT NULL (auto-populated by database trigger)

    Custom attributes:
    - randoms: List for temporary data (not stored in database)
    """

    __tablename__ = 'images'
    __table_args__ = {'extend_existing': True}

    # Explicitly define columns for SQLAlchemy ORM
    id = Column(Integer, primary_key=True)
    file_name = Column(String(255), unique=True, nullable=False)
    is_masc_human = Column(Boolean, nullable=True)
    is_masc_prediction = Column(Boolean, nullable=True)
    hash = Column(String(255), nullable=False)

    def __init__(self, *args, **kwargs):
        """Initialize the Image model with an empty randoms list."""
        super().__init__(*args, **kwargs)
        self.random_files = []

    def __repr__(self):
        """String representation of the Image model."""
        return f'<Image {self.file_name}>'

    def to_dict(self):
        """Convert the Image object to a dictionary."""
        return {
            'id': self.id,
            'file_name': self.file_name,
            'is_masc_human': self.is_masc_human,
            'is_masc_prediction': self.is_masc_prediction,
            'hash': self.hash,
            'random_files': self.random_files
        }

    @classmethod
    def get_random_unclassified(cls, limit=10):
        """Get random samples of images where is_masc_human IS NULL"""
        return cls.query.filter(
            cls.is_masc_human.is_(None)
        ).order_by(func.random()).limit(limit).all()

    @classmethod
    def get_random_classified(cls, limit=10):
        """Get random image samples where is_masc_human is NOT NULL."""
        return cls.query.filter(
            cls.is_masc_human.isnot(None)
        ).order_by(func.random()).limit(limit).all()

    @classmethod
    def update_gender(cls, file_name: str, is_masc: bool) -> None:
        """ Updates the Gender, by human for a certain file name """

        result = cls.query.filter_by(file_name=file_name).update(
            {'is_masc_human': is_masc}
        )
        if result == 0:
            # No rows were updated, meaning the file_name wasn't found
            raise ValueError(f"Image with file_name '{file_name}' not found")

        session.commit()
