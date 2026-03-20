# Classifier Rules

`knowledge/classifier.py` maintains only the exemption list. The LLM decides whether to explain everything else.

## When to edit classifier.py

Only when cc-teacher is explaining something too obvious. Add a regex to `SIMPLE_BASH_PATTERNS`:

```python
r"^my-command(\s|$)",
```

Or add a filename/extension to `SIMPLE_FILE_NAMES` / `SIMPLE_FILE_EXTENSIONS`.

## Verify after editing

```bash
# Should return None (exempted)
python3 -c "from knowledge.classifier import classify_bash; print(classify_bash('my-command --flag'))"

# Should still return a dict (not exempted)
python3 -c "from knowledge.classifier import classify_bash; print(classify_bash('docker compose up -d'))"
```
