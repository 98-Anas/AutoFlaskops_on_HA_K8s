import pytest
from app import app as flask_app
import os
import json

@pytest.fixture
def app():
    """Create and configure a new app instance for each test."""
    # Configure the app for testing
    flask_app.config['TESTING'] = True
    flask_app.config['WTF_CSRF_ENABLED'] = False
    
    # Set test database configuration
    flask_app.config['MYSQL_DATABASE_USER'] = 'test_user'
    flask_app.config['MYSQL_DATABASE_PASSWORD'] = 'test_password'
    flask_app.config['MYSQL_DATABASE_DB'] = 'test_db'
    flask_app.config['MYSQL_DATABASE_HOST'] = 'localhost'
    
    yield flask_app

@pytest.fixture
def client(app):
    """A test client for the app."""
    return app.test_client()

@pytest.fixture
def runner(app):
    """A test runner for the app's Click commands."""
    return app.test_cli_runner()

@pytest.fixture
def mock_db(mocker):
    """Mock database connection and cursor."""
    mock_connection = mocker.patch('app.mysql.connect')
    mock_cursor = mocker.MagicMock()
    mock_connection.return_value.cursor.return_value = mock_cursor
    return mock_connection, mock_cursor

@pytest.fixture
def sample_user_data():
    """Sample user data for testing."""
    return {
        'inputName': 'Test User',
        'inputEmail': 'test@example.com',
        'inputPassword': 'testpassword123'
    }

@pytest.fixture
def sample_wish_data():
    """Sample wish data for testing."""
    return {
        'inputTitle': 'Test Wish',
        'inputDescription': 'This is a test wish description'
    }

@pytest.fixture
def mock_session():
    """Mock session data."""
    return {'user': 1}
