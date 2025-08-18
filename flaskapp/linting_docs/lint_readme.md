# 🔍 Linting and Code Style

This project uses **flake8** for Python linting and style checking.
Linting ensures that the codebase remains clean, consistent, and free of common pitfalls.

---

## 📦 Installation

Install linting dependencies from `lintReqs.txt`:

```bash
pip install -r lintReqs.txt
```

### Minimal requirements (for HTML report only)

```txt
flake8==7.1.1
flake8-html
```

### Full requirements (for stricter style enforcement)

```txt
# Linting and formatting dependencies
flake8==7.1.1
flake8-docstrings==1.7.0
flake8-import-order==0.18.2
flake8-bugbear==24.4.26
flake8-html
black==24.4.2
isort==5.13.2
```

---

## 🛠 Usage

### 1. Run Flake8 (CLI)

Check code for linting errors:

```bash
flake8 app.py
```

By default, this will show warnings/errors in the terminal.

---

### 2. Generate an HTML Report

To produce a detailed report:

```bash
flake8 app.py --format=html --htmldir=flake8-report --exit-zero
```

* `--format=html` → output report in HTML format
* `--htmldir=flake8-report` → directory where reports will be saved
* `--exit-zero` → ensures the command always exits with **status 0** (CI pipelines will not fail even if issues exist)

After running, open:

```bash
flake8-report/index.html
```

in a browser to view the report.

---

### 3. Auto-formatting (Optional)

* **Black** → format code:

```bash
black app.py
```

* **Isort** → sort imports:

```bash
isort app.py
```

These commands automatically fix formatting issues, reducing manual lint errors.

---

## ⚙️ CI/CD Integration

In GitLab CI/CD pipelines, you can add a linting stage without breaking builds:

```yaml
lint:
  stage: lint
  image: python:3.12
  script:
    - pip install -r lintReqs.txt
    - flake8 app.py --format=html --htmldir=flake8-report --exit-zero
  artifacts:
    paths:
      - flake8-report
    expire_in: 7 days
```

This ensures the HTML report is generated and uploaded as a pipeline artifact while allowing the pipeline to pass.

---

## ✅ Summary

* **flake8** → linting engine
* **flake8-html** → generates HTML reports
* **black + isort** → auto-format code (optional but recommended)
* **exit-zero** → ensures pipelines don’t fail due to linting issues
