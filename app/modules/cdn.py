import random
from .s3_access import S3Access


class CDN(S3Access):
    """CDN class for managing CDN operations with S3 bucket access."""

    def __init__(self, bucket_name, cdn_url):
        """
        Initialize CDN with bucket name and CDN URL.

        Args:
            bucket_name (str): Name of the S3 bucket to connect to
            cdn_url (str): Public facing URL of the CDN
                          (e.g., 'https://cdn.example.com')
        """
        super().__init__(bucket_name)
        self.cdn_url = cdn_url.rstrip('/')  # Remove trailing slash

    def get_image_url(self, filename) -> str:
        """
        Generate the full CDN URL for an image in the sources folder.

        Args:
            filename (str): Name of the file in the S3 sources folder

        Returns:
            str: Full CDN URL for the image
        """
        # Construct the full URL by combining CDN URL with sources folder
        # and filename
        full_url = f"{self.cdn_url}/{filename}"
        return full_url

    def get_random(self):
        """
        Get a random image from the sources folder.

        Returns:
            tuple: (full_cdn_url, filename) or (None, None) if no images
                   found
        """

        sources = self.list_sources()

        if not sources:
            return None, None

        # Filter out the folder itself and get only files
        files = [key for key in sources if not key.endswith('/')]

        if not files:
            return None, None

        random_key = random.choice(files)
        filename = random_key.replace('sources/', '')
        full_url = self.get_image_url(filename)

        return full_url, filename
