from pathlib import Path
from dotenv import load_dotenv


def load_environment() -> None:
    """Load environment variables from the project root .env file."""
    env_path = Path(__file__).resolve().parents[1] / ".env"
    load_dotenv(env_path)
    # Also load a plain .env in the current working directory for flexibility.
    load_dotenv()


load_environment()
