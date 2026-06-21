import os
import time
import re
import fitz
from pinecone import Pinecone, ServerlessSpec
from dotenv import load_dotenv

load_dotenv()

# ─── CONFIG ───────────────────────────────────────────────────
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
INDEX_NAME = "smart-posture-app"
CHUNK_SIZE = 400
CHUNK_OVERLAP = 50

BOOK_PAGE_RANGES = {
    "kisner": [
        (1, 36),
        (65, 108),
        (147, 230),
        (295, 308),
        (383, 480),
    ],
    "brotzman": [
        (530, 542),
        (555, 620),
    ],
    "janda": None,
    "posture": None,
    "red_flag": None,
    "piem": None,
    "nutrition": None,
    "sosort": None,
}

PDF_FILES = {
    "kisner":    "kisner_colby.pdf",
    "brotzman":  "brotzman_wilk.pdf",
    "janda":     "janda.pdf",
    "posture":   "posture_stand_tall.epub",
    "red_flag":  "red_flags_spinal.pdf",
    "piem":      "piem_pain_checklists.pdf",
    "nutrition": "rehabilitation_nutrition.pdf",
    "sosort":    "sosort_guidelines.pdf",
}

PDF_FOLDER = "pdfs"


# ─── EXTRACT TEXT ─────────────────────────────────────────────
def extract_text_from_pdf(filepath, page_ranges=None):
    doc = fitz.open(filepath)
    total_pages = len(doc)
    extracted_pages = []

    if page_ranges is None:
        pages_to_extract = range(total_pages)
    else:
        pages_to_extract = set()
        for (start, end) in page_ranges:
            for p in range(start - 1, min(end, total_pages)):
                pages_to_extract.add(p)

    for page_num in sorted(pages_to_extract):
        page = doc[page_num]
        text = page.get_text()
        if text.strip():
            extracted_pages.append({
                "text": text,
                "page_num": page_num + 1
            })

    doc.close()
    print(f"  → Extracted {len(extracted_pages)} pages")
    return extracted_pages


# ─── CHUNK TEXT ───────────────────────────────────────────────
def chunk_text(pages, book_name, chunk_size=CHUNK_SIZE, overlap=CHUNK_OVERLAP):
    chunks = []
    full_text = ""
    for page in pages:
        full_text += f" {page['text']}"

    full_text = re.sub(r'\s+', ' ', full_text).strip()
    words = full_text.split()
    total_words = len(words)

    chunk_id = 0
    start = 0

    while start < total_words:
        end = min(start + chunk_size, total_words)
        chunk_words = words[start:end]
        chunk_text_str = ' '.join(chunk_words)

        if len(chunk_words) > 50:
            chunks.append({
                "id": f"{book_name}_chunk_{chunk_id}",
                "text": chunk_text_str,
                "book": book_name,
                "chunk_index": chunk_id,
                "word_count": len(chunk_words)
            })
            chunk_id += 1

        start += chunk_size - overlap

    print(f"  → Created {len(chunks)} chunks")
    return chunks


# ─── CREATE EMBEDDINGS ────────────────────────────────────────
def create_embeddings_pinecone(chunks, pc):
    texts = [chunk["text"] for chunk in chunks]
    total = len(texts)
    print(f"  → Creating embeddings for {total} chunks...")

    embeddings = []
    batch_size = 30

    for i in range(0, total, batch_size):
        batch = texts[i:i + batch_size]
        retry_count = 0

        while True:
            try:
                result = pc.inference.embed(
                    model='multilingual-e5-large',
                    inputs=batch,
                    parameters={'input_type': 'passage', 'truncate': 'END'}
                )
                # result is a list of objects with 'values'
                for item in result:
                    embeddings.append(list(item['values']))

                batch_num = i // batch_size + 1
                total_batches = (total + batch_size - 1) // batch_size
                print(f"  → Batch {batch_num}/{total_batches} done ({min(i + batch_size, total)}/{total} chunks)")

                if i + batch_size < total:
                    print(f"  ⏳ Waiting 45s...")
                    time.sleep(45)
                break

            except Exception as e:
                retry_count += 1
                error_str = str(e).lower()

                if '429' in str(e) or 'resource_exhausted' in error_str:
                    wait = 90 * retry_count
                    print(f"  ⚠️ Rate limit, waiting {wait}s... (retry {retry_count})")
                    time.sleep(wait)
                elif 'timeout' in error_str or 'timed out' in error_str:
                    wait = 60 * retry_count
                    print(f"  ⚠️ Timeout, waiting {wait}s... (retry {retry_count})")
                    time.sleep(wait)
                else:
                    print(f"  ❌ Unexpected error: {e}")
                    raise e

                if retry_count > 10:
                    print(f"  ❌ Too many retries on batch {i//batch_size + 1}, skipping")
                    # Add empty placeholders so indexes stay aligned
                    for _ in batch:
                        embeddings.append([0.0] * 1024)
                    break

    return embeddings


# ─── UPLOAD TO PINECONE ───────────────────────────────────────
def upload_to_pinecone(chunks, embeddings, index):
    batch_size = 100

    for i in range(0, len(chunks), batch_size):
        batch_chunks = chunks[i:i + batch_size]
        batch_embeddings = embeddings[i:i + batch_size]

        vectors = []
        for chunk, embedding in zip(batch_chunks, batch_embeddings):
            vectors.append({
                "id": chunk["id"],
                "values": list(embedding),  # always a plain list, no .tolist() needed
                "metadata": {
                    "text": chunk["text"],
                    "book": chunk["book"],
                    "chunk_index": chunk["chunk_index"],
                }
            })

        index.upsert(vectors=vectors)
        print(f"  → Uploaded batch {i//batch_size + 1}")


# ─── MAIN ─────────────────────────────────────────────────────
def main():
    print("🚀 Starting Smart Posture RAG Pipeline\n")

    # Connect to Pinecone
    print("🔗 Connecting to Pinecone...")
    pc = Pinecone(api_key=PINECONE_API_KEY)

    existing_indexes = [idx.name for idx in pc.list_indexes()]
    if INDEX_NAME not in existing_indexes:
        print(f"  → Creating index '{INDEX_NAME}'...")
        pc.create_index(
            name=INDEX_NAME,
            dimension=1024,
            metric="cosine",
            spec=ServerlessSpec(cloud="aws", region="us-east-1")
        )
        print("  → Index created ✅")
    else:
        print(f"  → Index '{INDEX_NAME}' already exists ✅")

    index = pc.Index(INDEX_NAME)
    print("✅ Connected to Pinecone\n")

    # Process all books
    all_chunks = []

    for book_key, filename in PDF_FILES.items():
        filepath = os.path.join(PDF_FOLDER, filename)

        if not os.path.exists(filepath):
            print(f"⚠️  File not found, skipping: {filepath}")
            continue

        print(f"📖 Processing: {filename}")

        if filename.endswith('.epub'):
            print("  → EPUB detected, converting...")
            try:
                import ebooklib
                from ebooklib import epub
                from bs4 import BeautifulSoup

                book = epub.read_epub(filepath)
                full_text = ""
                for item in book.get_items():
                    if item.get_type() == ebooklib.ITEM_DOCUMENT:
                        soup = BeautifulSoup(item.get_content(), 'html.parser')
                        full_text += soup.get_text() + " "

                pages = [{"text": full_text, "page_num": 1}]
            except Exception as e:
                print(f"  ⚠️ Could not read EPUB: {e}, skipping...")
                continue
        else:
            page_ranges = BOOK_PAGE_RANGES.get(book_key, None)
            pages = extract_text_from_pdf(filepath, page_ranges)

        if not pages:
            print(f"  ⚠️ No text extracted, skipping...")
            continue

        chunks = chunk_text(pages, book_key)
        all_chunks.extend(chunks)
        print(f"✅ Done: {filename}\n")

    if not all_chunks:
        print("❌ No chunks created. Check your PDF files.")
        return

    total_chunks = len(all_chunks)
    print(f"📊 Total chunks: {total_chunks}")

    # ── Check how many already uploaded ──────────────────────
    stats = index.describe_index_stats()
    already_uploaded = stats['total_vector_count']
    print(f"📊 Already in Pinecone: {already_uploaded} vectors")

    if already_uploaded >= total_chunks:
        print("✅ All chunks already uploaded! Nothing to do.")
        return

    # Resume from where we left off
    chunks_to_process = all_chunks[already_uploaded:]
    print(f"📊 Resuming from chunk {already_uploaded}, {len(chunks_to_process)} remaining\n")

    # Create embeddings
    print("🧠 Creating embeddings...")
    embeddings = create_embeddings_pinecone(chunks_to_process, pc)

    # Upload
    print(f"\n☁️  Uploading {len(chunks_to_process)} chunks to Pinecone...")
    upload_to_pinecone(chunks_to_process, embeddings, index)

    # Final count
    final_stats = index.describe_index_stats()
    print(f"\n✅ Pipeline complete!")
    print(f"   Total vectors in Pinecone: {final_stats['total_vector_count']}")


if __name__ == "__main__":
    main()