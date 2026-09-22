/*
===============================================================================
Palestra Infnet 202609
RAG de Ponta a Ponta no SQL Server 2025

Hands On: Busca Vetorial

Objetivo:
Demonstrar busca vetorial em embeddings gerados por uma LLM.

Ambiente:
- SQL Server 2025
- Ollama
- Caddy

Autor: Landry Duailibe
===============================================================================
*/
use Landry_Blogs
go

/**************************************
 Criar o índice vetorial
***************************************/
DROP INDEX IF EXISTS IX_BlogChunks_PorTamanho ON dbo.BlogChunks_PorTamanho
go
CREATE VECTOR INDEX IX_BlogChunks_PorTamanho
ON dbo.BlogChunks_PorTamanho (Embedding)
WITH (METRIC = 'cosine', TYPE = 'diskann')
go


-- Verificar a criação do índice vetorial
SELECT i.[name] as Nome_Indice,
i.[type_desc] as Tipo,
vi.distance_metric as Metrica,
vi.vector_index_type as Algoritmo,
vi.build_parameters as Parametros
FROM sys.indexes i
JOIN sys.vector_indexes vi ON vi.object_id = i.object_id AND vi.index_id  = i.index_id
WHERE object_name(i.object_id) like 'BlogChunks%'

/**************************************
 Busca semântica - VECTOR_SEARCH()
***************************************/
go
DECLARE @Pergunta varchar(2000) = 'Como diagnosticar crescimento do log da TempDB?'
DECLARE @VetorPergunta vector(768) = ai_generate_embeddings(@Pergunta USE MODEL EmbeddingGemma)
DECLARE @Top int = 5

-- Chunk Tamanho Fixo
SELECT bp.Titulo, bc.Chunk_Texto as ChunkFixo, vs.distance as Distancia
FROM vector_search(
TABLE = dbo.BlogChunks_PorTamanho AS bc,
COLUMN = Embedding,
SIMILAR_TO = @VetorPergunta,
METRIC = 'cosine',
TOP_N  = @Top
) as vs

JOIN dbo.BlogPosts bp ON bp.PostId = bc.PostId
ORDER BY vs.distance

-- Chunk Tamanho Variável (apenas na palestra)
SELECT bp.Titulo, bc.Chunk_Texto as ChunkVariavel, vs.distance as Distancia
FROM vector_search(
TABLE = dbo.BlogChunks AS bc,
COLUMN = Embedding,
SIMILAR_TO = @VetorPergunta,
METRIC = 'cosine',
TOP_N  = @Top
) as vs

JOIN dbo.BlogPosts bp ON bp.PostId = bc.PostId
ORDER BY vs.distance
go

/*******************************************************
 Busca semântica - VECTOR_DISTANCE()
*********************************************************/
go
DECLARE @Pergunta varchar(2000) = 'Como diagnosticar crescimento do log da TempDB?'
DECLARE @VetorPergunta vector(768) = ai_generate_embeddings(@Pergunta USE MODEL EmbeddingGemma)

-- Chunk Tamanho Fixo
SELECT TOP (5) bp.Titulo, bc.Chunk_Texto as ChunkFixo,
vector_distance('cosine', bc.Embedding, @VetorPergunta) as Distancia
FROM dbo.BlogChunks_PorTamanho bc
INNER JOIN dbo.BlogPosts bp ON bp.PostId = bc.PostId
ORDER BY Distancia ASC

-- Chunk Tamanho Variável (apenas na palestra)
SELECT TOP (5) bp.Titulo, bc.Chunk_Texto as ChunkVariavel,
vector_distance('cosine', bc.Embedding, @VetorPergunta) as Distancia
FROM dbo.BlogChunks bc
INNER JOIN dbo.BlogPosts bp ON bp.PostId = bc.PostId
ORDER BY Distancia ASC
go
