from fastapi import FastAPI
from src.infrastructure.adapters.input.controllers.simulator_controller import router as simulator_router

app = FastAPI(
    title="Smart Overdose Detector API",
    description="Backend implementation using Hexagonal Architecture for PMV 1",
    version="1.0.0"
)

app.include_router(simulator_router)

@app.get("/")
def health_check():
    return {"status": "ok", "message": "Smart Overdose Detector API is running."}

# Entrypoint for local testing
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("src.main:app", host="0.0.0.0", port=8000, reload=True)
