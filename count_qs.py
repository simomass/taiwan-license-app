import json
import os

with open('assets/questions.json', 'r', encoding='utf-8') as f:
    qs = json.load(f)

video = [q for q in qs if q.get('source') == 'pdf_2.pdf']
other = [q for q in qs if q.get('source') != 'pdf_2.pdf']
print(f"Total video questions: {len(video)}")
print(f"Total other questions: {len(other)}")
