#!/usr/bin/env python3
"""
Test runner script for Flask application
Runs pytest with coverage reporting
"""

import sys
import os
import subprocess

def run_tests():
    """Run all tests with coverage reporting."""
    print("🧪 Running Flask Application Tests...")
    print("=" * 50)
    
    # Change to flaskapp directory
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    # Run pytest with coverage
    cmd = [
        "python", "-m", "pytest",
        "tests/",
        "-v",
        "--cov=app",
        "--cov-report=html",
        "--cov-report=term-missing",
        "--cov-fail-under=80",
        "--cov-report=xml:coverage.xml"
    ]
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print("✅ All tests passed!")
        print("\n📊 Coverage Report:")
        print(result.stdout)
        
        # Display HTML coverage report location
        print("\n📈 HTML Coverage Report:")
        print("Open 'htmlcov/index.html' in your browser to view detailed coverage")
        
    except subprocess.CalledProcessError as e:
        print("❌ Tests failed!")
        print("\n📋 Error Output:")
        print(e.stdout)
        print(e.stderr)
        sys.exit(1)

if __name__ == "__main__":
    run_tests()
