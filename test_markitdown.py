from markitdown import MarkItDown

markitdown = MarkItDown()
result = markitdown.convert("pdf_2.pdf")

with open("pdf_2.md", "w", encoding="utf-8") as f:
    f.write(result.text_content)

print("Converted pdf_2.pdf to pdf_2.md")
