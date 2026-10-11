"""
VPC Architecture Demo API
FastAPI app running on EC2 in a private subnet.
Connects to RDS PostgreSQL in a separate private subnet.
Accessed via ALB in a public subnet.
"""

import os
import logging
from contextlib import asynccontextmanager

import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional

# ── Logger ────────────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ── Config ────────────────────────────────────────────────────────────────────
# All injected via EC2 user data or environment variables
DB_HOST     = os.environ.get("DB_HOST", "localhost")
DB_PORT     = os.environ.get("DB_PORT", "5432")
DB_NAME     = os.environ.get("DB_NAME", "portfolio")
DB_USER     = os.environ.get("DB_USER", "postgres")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "prod")


# ── Database helpers ──────────────────────────────────────────────────────────

def get_db_connection():
    """Open a connection to RDS PostgreSQL."""
    return psycopg2.connect(
        host     = DB_HOST,
        port     = DB_PORT,
        dbname   = DB_NAME,
        user     = DB_USER,
        password = DB_PASSWORD,
        connect_timeout = 5,
    )


def init_db():
    """Create the notes table if it does not exist."""
    try:
        conn = get_db_connection()
        cur  = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS notes (
                id         SERIAL PRIMARY KEY,
                title      VARCHAR(255) NOT NULL,
                content    TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        conn.commit()
        cur.close()
        conn.close()
        logger.info("Database initialised successfully")
    except Exception as e:
        logger.error("Failed to initialise database: %s", e)


# ── Lifespan ──────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting up — connecting to RDS at %s", DB_HOST)
    init_db()
    yield
    logger.info("Shutting down")


# ── App ───────────────────────────────────────────────────────────────────────

app = FastAPI(
    title       = "VPC Architecture Demo",
    description = """
A FastAPI service running on EC2 in a **private subnet**, backed by
RDS PostgreSQL in a **separate private subnet**, accessed via an
ALB in a **public subnet**.

Demonstrates production-grade AWS VPC design:
- Public subnets: ALB, NAT Gateway
- Private subnets: EC2, RDS
- No direct internet access to application or database tiers
    """,
    version  = APP_VERSION,
    lifespan = lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins = ["*"],
    allow_methods = ["GET", "POST", "DELETE"],
    allow_headers = ["*"],
)


# ── Models ────────────────────────────────────────────────────────────────────

class NoteCreate(BaseModel):
    title:   str
    content: str

class Note(BaseModel):
    id:         int
    title:      str
    content:    str
    created_at: str


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/", summary="Service info", tags=["General"])
async def root():
    """Returns info about the service and its network position."""
    db_status = "unreachable"
    try:
        conn = get_db_connection()
        conn.close()
        db_status = "connected"
    except Exception as e:
        logger.warning("DB health check failed: %s", e)

    return {
        "service":     "VPC Architecture Demo",
        "version":     APP_VERSION,
        "environment": ENVIRONMENT,
        "network": {
            "this_service":  "EC2 in private subnet",
            "database":      f"RDS PostgreSQL at {DB_HOST} ({db_status})",
            "load_balancer": "ALB in public subnet",
            "internet_access": "Via NAT Gateway (outbound only)",
        },
    }


@app.get("/health", summary="Health check", tags=["General"])
async def health():
    """
    ALB health check endpoint.
    Also checks the database connection so the ALB can detect DB issues.
    """
    try:
        conn = get_db_connection()
        conn.close()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        logger.error("Health check failed: %s", e)
        raise HTTPException(
            status_code = 503,
            detail      = f"Database unreachable: {str(e)}"
        )


@app.get("/notes", summary="List all notes", tags=["Notes"])
async def list_notes():
    """Retrieve all notes from RDS PostgreSQL."""
    try:
        conn  = get_db_connection()
        cur   = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT * FROM notes ORDER BY created_at DESC")
        notes = cur.fetchall()
        cur.close()
        conn.close()
        return {"notes": [dict(n) for n in notes], "count": len(notes)}
    except Exception as e:
        logger.exception("Failed to list notes: %s", e)
        raise HTTPException(status_code=500, detail="Database error")


@app.post("/notes", summary="Create a note", tags=["Notes"], status_code=201)
async def create_note(note: NoteCreate):
    """Store a new note in RDS PostgreSQL."""
    try:
        conn = get_db_connection()
        cur  = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "INSERT INTO notes (title, content) VALUES (%s, %s) RETURNING *",
            (note.title, note.content)
        )
        created = dict(cur.fetchone())
        conn.commit()
        cur.close()
        conn.close()
        return {"message": "Note created", "note": created}
    except Exception as e:
        logger.exception("Failed to create note: %s", e)
        raise HTTPException(status_code=500, detail="Database error")


@app.delete("/notes/{note_id}", summary="Delete a note", tags=["Notes"])
async def delete_note(note_id: int):
    """Delete a note by ID from RDS PostgreSQL."""
    try:
        conn = get_db_connection()
        cur  = conn.cursor()
        cur.execute(
            "DELETE FROM notes WHERE id = %s RETURNING id",
            (note_id,)
        )
        deleted = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()

        if not deleted:
            raise HTTPException(status_code=404, detail=f"Note {note_id} not found")

        return {"message": f"Note {note_id} deleted"}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to delete note: %s", e)
        raise HTTPException(status_code=500, detail="Database error")
