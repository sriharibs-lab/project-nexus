"""
SUPERSEDED — do NOT use this file as the WSGI/ASGI entry point.

The real application lives at:  app/main.py  (module: app.main)
Deploy target:  uvicorn app.main:app --host 0.0.0.0 --port 8000
See Procfile for the pinned command.

This file exists only as an artefact of the initial scaffold commit.
It will be removed in a future cleanup pass.
"""

raise ImportError(
    "api/main.py is a superseded scaffold stub. "
    "Use 'app.main:app' as the ASGI entry point. "
    "See api/Procfile for the correct command."
)
