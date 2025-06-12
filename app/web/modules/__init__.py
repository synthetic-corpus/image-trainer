"""
S3 and CDN modules for image trainer application.

This package provides classes for managing S3 operations and CDN functionality.
"""

from .s3_access import S3Access
from .cdn import CDN

__all__ = ['S3Access', 'CDN']
