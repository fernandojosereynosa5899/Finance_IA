const isServer = typeof window === 'undefined';
export const API_URL = isServer 
    ? (import.meta.env.INTERNAL_API_URL || import.meta.env.PUBLIC_API_URL || "http://localhost:8080")
    : (import.meta.env.PUBLIC_API_URL || "http://localhost:8080");