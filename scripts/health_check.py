"""
Health check script for Docker container
"""
import sys
import httpx
import asyncio
from typing import Dict, Any

async def check_health() -> Dict[str, Any]:
    """Check application health"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get("http://localhost:8000/health", timeout=10.0)
            if response.status_code == 200:
                return {
                    "status": "healthy",
                    "response": response.json()
                }
            else:
                return {
                    "status": "unhealthy",
                    "error": f"HTTP {response.status_code}"
                }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e)
        }

async def main():
    """Main health check function"""
    result = await check_health()
    
    if result["status"] == "healthy":
        print("✅ Health check passed")
        sys.exit(0)
    else:
        print(f"❌ Health check failed: {result['error']}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
