import fitz
import re

def dump_q(pdf_name, q_str):
    doc = fitz.open(pdf_name)
    for i in range(len(doc)):
        blocks = doc[i].get_text("blocks")
        for b in blocks:
            if b[6] != 0: continue
            if q_str in b[4]:
                print(f"Page {i}:")
                for bb in sorted(blocks, key=lambda x: (x[1], x[0])):
                    if bb[6] == 0:
                        print(f"y0: {bb[1]:.1f}, x0: {bb[0]:.1f} | {repr(bb[4].strip())}")
                return

dump_q("pdf_1.pdf", "No motorcycles other than large")
dump_q("pdf_6.pdf", "Crossroads ahead")
