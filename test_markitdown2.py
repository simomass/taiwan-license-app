from markitdown import MarkItDown

md = MarkItDown()
result = md.convert("pdf_1.pdf")
with open("pdf_1.md", "w", encoding="utf-8") as f:
    f.write(result.text_content)
print("Converted pdf_1.pdf to pdf_1.md")
