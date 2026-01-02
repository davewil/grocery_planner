from fastapi import FastAPI

app = FastAPI(title="GroceryPlanner AI Service")

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "grocery-planner-ai"}

@app.get("/")
def root():
    return {"message": "GroceryPlanner AI Service is running"}
