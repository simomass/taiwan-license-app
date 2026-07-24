import json

with open('assets/questions.json', 'r', encoding='utf-8') as f:
    qs = json.load(f)

empty_qs = [q for q in qs if not q.get('question', '').strip()]
print(f"Empty question text count: {len(empty_qs)}")
if empty_qs:
    print(empty_qs[0])
