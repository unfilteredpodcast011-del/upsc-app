import json
import urllib.request
import urllib.parse
import concurrent.futures
import time
import os

def translate_one(text, target):
    if not text or not str(text).strip():
        return text
    url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=' + target + '&dt=t&q=' + urllib.parse.quote(str(text))
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=12) as res:
                data = json.loads(res.read().decode('utf-8'))
                return ''.join([part[0] for part in data[0] if part[0]])
        except Exception:
            time.sleep(0.5)
    return text

def process_file(file_path):
    print(f"Processing: {file_path}")
    with open(file_path, 'r', encoding='utf-8') as f:
        questions = json.load(f)

    # Check if already translated
    if questions and 'translations' in questions[0] and 'ta' in questions[0]['translations'] and 'hi' in questions[0]['translations']:
        print(f"Already translated: {file_path}")
        return

    total = len(questions)
    print(f"Total questions to translate: {total}")

    def translate_question_item(item):
        en_q = item.get('question', '')
        en_opts = item.get('options', {})
        en_exp = item.get('explanation', '')

        # Translate to Tamil
        ta_q = translate_one(en_q, 'ta')
        ta_opts = {k: translate_one(v, 'ta') for k, v in en_opts.items()}
        ta_exp = translate_one(en_exp, 'ta') if en_exp else ''

        # Translate to Hindi
        hi_q = translate_one(en_q, 'hi')
        hi_opts = {k: translate_one(v, 'hi') for k, v in en_opts.items()}
        hi_exp = translate_one(en_exp, 'hi') if en_exp else ''

        item['translations'] = {
            'en': {
                'question': en_q,
                'options': en_opts,
                'explanation': en_exp
            },
            'ta': {
                'question': ta_q,
                'options': ta_opts,
                'explanation': ta_exp
            },
            'hi': {
                'question': hi_q,
                'options': hi_opts,
                'explanation': hi_exp
            }
        }
        return item

    # Use ThreadPoolExecutor for fast translation
    with concurrent.futures.ThreadPoolExecutor(max_workers=25) as executor:
        results = list(executor.map(translate_question_item, questions))

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"Successfully translated and updated: {file_path}")

if __name__ == '__main__':
    base_dir = r'C:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\assets\data'
    upsc_path = os.path.join(base_dir, 'upsc_questions.json')
    tnpsc_path = os.path.join(base_dir, 'tnpsc_questions.json')

    t0 = time.time()
    process_file(upsc_path)
    process_file(tnpsc_path)
    print(f"Completed all translations in {time.time() - t0:.2f} seconds")
