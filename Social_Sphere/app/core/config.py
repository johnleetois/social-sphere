import os
from dotenv import load_dotenv

load_dotenv()

# OLD PostgreSQL / NeonDB
DATABASE_URL = os.getenv("DATABASE_URL")

# Auth settings
SECRET_KEY = os.getenv("SECRET_KEY", "change_this_secret_key")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 60))

# NEW MongoDB Atlas
MONGODB_URI = os.getenv("MONGODB_URI")
MONGODB_DB_NAME = os.getenv("MONGODB_DB_NAME", "social-sphere")