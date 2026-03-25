import os
import asyncio
import time
import json

# Worker: scan backend_api/data/ for entries with image_path and process them
DATA_DIR = os.path.join(os.path.dirname(__file__), 'data')


async def process_image_record(rec, engine):
    path = rec.get('image_path')
    if not path or not os.path.exists(path):
        return None
    import cv2
    img = cv2.imread(path)
    # If engine is None (stub mode), return a placeholder vector
    if engine is None:
        vec = [0.0] * 512
        score = 0.0
    else:
        vec, score = engine.run_inference(img)

    return {
        'vector': vec,
        'score': score,
        'image_path': path,
        'processed_at': time.time(),
        'original': rec,
    }


async def worker_loop(model_path=None, architecture='ir_50', device='cpu', stub=False):
    # load engine unless running in stub mode
    engine = None
    if not stub:
        # import here to avoid requiring heavy deps when running stub mode
        from ai_research.inference import AdaFaceInference
        engine = AdaFaceInference(
            model_path=model_path or 'models/adaface_ir101_ms1mv3.ckpt',
            architecture=architecture,
            device=device,
        )

    out_path = os.path.join(DATA_DIR, 'processed.jsonl')
    os.makedirs(DATA_DIR, exist_ok=True)
    input_path = os.path.join(DATA_DIR, 'embeddings.jsonl')

    while True:
        if os.path.exists(input_path):
            with open(input_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()

            remaining = []
            for line in lines:
                try:
                    rec = json.loads(line)
                except Exception:
                    continue

                # Case A: record has an image_path -> run inference or stub processing
                if rec.get('image_path') and not rec.get('processed'):
                    result = await process_image_record(rec, engine)
                    if result:
                        with open(out_path, 'a', encoding='utf-8') as out:
                            out.write(json.dumps(result, ensure_ascii=False) + '\n')
                        rec['processed'] = True
                # Case B: record already contains a vector (embeddings extracted on-device)
                elif rec.get('vector') and not rec.get('processed'):
                    # Move vector to processed output so downstream can consume it
                    result = {
                        'vector': rec.get('vector'),
                        'score': rec.get('score', 1.0),
                        'image_path': rec.get('image_path'),
                        'processed_at': time.time(),
                        'original': rec,
                    }
                    with open(out_path, 'a', encoding='utf-8') as out:
                        out.write(json.dumps(result, ensure_ascii=False) + '\n')
                    rec['processed'] = True

                remaining.append(rec)

            # overwrite file with updated flags
            with open(input_path, 'w', encoding='utf-8') as f:
                for r in remaining:
                    f.write(json.dumps(r, ensure_ascii=False) + '\n')

        await asyncio.sleep(2)


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('--model_path', default=None)
    parser.add_argument('--arch', default='ir_50')
    parser.add_argument('--device', default='cpu')
    parser.add_argument('--stub', action='store_true', help='Run worker in stub mode (no torch required)')
    args = parser.parse_args()

    asyncio.run(
        worker_loop(model_path=args.model_path, architecture=args.arch, device=args.device, stub=args.stub)
    )
