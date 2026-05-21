from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import MONGODB_URI, MONGODB_DB_NAME

mongo_client = None
mongo_db = None


async def connect_to_mongo():
    global mongo_client, mongo_db

    if not MONGODB_URI:
        raise Exception("MONGODB_URI is missing in .env")

    mongo_client = AsyncIOMotorClient(MONGODB_URI)
    mongo_db = mongo_client[MONGODB_DB_NAME]

    # Test connection
    await mongo_client.admin.command("ping")

    print(f"MongoDB Atlas connected successfully: {MONGODB_DB_NAME}")


async def close_mongo_connection():
    global mongo_client

    if mongo_client:
        mongo_client.close()
        print("MongoDB connection closed")


def get_mongo_db():
    if mongo_db is None:
        raise Exception("MongoDB is not connected")

    return mongo_db