"""
AirGuard AI - In-Memory High-Performance TTL Cache
Thread-safe and async-safe caching for stations, observations, and provider health.
"""
import asyncio
import time
from typing import Any, Dict, Optional, Tuple


class CacheEntry:
    def __init__(self, value: Any, ttl_seconds: float):
        self.value = value
        self.expires_at = time.time() + ttl_seconds
        self.created_at = time.time()

    def is_expired(self) -> bool:
        return time.time() >= self.expires_at


class EnvironmentalCache:
    def __init__(self):
        self._store: Dict[str, CacheEntry] = {}
        self._lock = asyncio.Lock()

    async def get(self, key: str) -> Optional[Any]:
        async with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return None
            if entry.is_expired():
                del self._store[key]
                return None
            return entry.value

    async def set(self, key: str, value: Any, ttl_seconds: float) -> None:
        async with self._lock:
            self._store[key] = CacheEntry(value, ttl_seconds)

    async def delete(self, key: str) -> None:
        async with self._lock:
            if key in self._store:
                del self._store[key]

    async def clear(self) -> None:
        async with self._lock:
            self._store.clear()

    async def get_stats(self) -> Dict[str, int]:
        async with self._lock:
            now = time.time()
            valid = sum(1 for e in self._store.values() if e.expires_at > now)
            return {"total_entries": len(self._store), "valid_entries": valid}


# Singleton cache instance
cache = EnvironmentalCache()
