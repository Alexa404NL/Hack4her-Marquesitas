-- DDL to set up the catalog vectorization schema in PostgreSQL using pgvector

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Drop table if exists to allow clean re-runs
-- DROP TABLE IF EXISTS catalogo_vectorizado;

-- Create table for vectorized catalog
CREATE TABLE IF NOT EXISTS catalogo_vectorizado (
    sku_solicitado BIGINT PRIMARY KEY,
    nombre_sku_solicitado TEXT NOT NULL,
    business_unit TEXT NOT NULL,
    embedding vector(768) NOT NULL
);

-- Create HNSW index for fast vector cosine similarity search
-- Note: m=16, ef_construction=64 are good general-purpose defaults.
CREATE INDEX IF NOT EXISTS catalogo_vectorizado_hnsw_idx 
ON catalogo_vectorizado USING hnsw (embedding vector_cosine_ops);
