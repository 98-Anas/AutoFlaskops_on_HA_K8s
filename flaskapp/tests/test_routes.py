import pytest
import json
from unittest.mock import patch, MagicMock

class TestRoutes:
    """Test all HTTP routes in the Flask application."""
    
    def test_main_route(self, client):
        """Test the main route returns index.html."""
        response = client.get('/')
        assert response.status_code == 200
        assert b'index.html' in response.data or b'<!DOCTYPE html>' in response.data
    
    def test_show_signup_route(self, client):
        """Test the showSignUp route."""
        response = client.get('/showSignUp')
        assert response.status_code == 200
        assert b'signup.html' in response.data or b'Sign Up' in response.data
    
    def test_show_signin_route(self, client):
        """Test the showSignIn route."""
        response = client.get('/showSignIn')
        assert response.status_code == 200
        assert b'signin.html' in response.data or b'Sign In' in response.data
    
    def test_show_add_wish_route(self, client):
        """Test the showAddWish route."""
        response = client.get('/showAddWish')
        assert response.status_code == 200
        assert b'addWish.html' in response.data or b'Add Wish' in response.data
    
    def test_user_home_unauthorized(self, client):
        """Test userHome route without authentication."""
        response = client.get('/userHome')
        assert response.status_code == 200
        assert b'Unauthorized Access' in response.data or b'error.html' in response.data
    
    def test_logout_route(self, client):
        """Test the logout route."""
        response = client.get('/logout')
        assert response.status_code == 302  # Redirect
        assert '/' in response.location
    
    @patch('app.mysql.connect')
    def test_signup_success(self, mock_connect, client, sample_user_data):
        """Test successful user signup."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []
        mock_connect.return_value.cursor.return_value = mock_cursor
        
        response = client.post('/signUp', data=sample_user_data)
        assert response.status_code == 200
        assert b'User created successfully' in response.data
    
    @patch('app.mysql.connect')
    def test_signup_missing_fields(self, mock_connect, client):
        """Test signup with missing fields."""
        response = client.post('/signUp', data={'inputName': '', 'inputEmail': '', 'inputPassword': ''})
        assert response.status_code == 200
        assert b'Enter the required fields' in response.data
    
    @patch('app.mysql.connect')
    def test_signup_duplicate_user(self, mock_connect, client, sample_user_data):
        """Test signup with duplicate user."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [('User already exists',)]
        mock_connect.return_value.cursor.return_value = mock_cursor
        
        response = client.post('/signUp', data=sample_user_data)
        assert response.status_code == 200
        assert b'error' in response.data
    
    @patch('app.mysql.connect')
    def test_validate_login_success(self, mock_connect, client):
        """Test successful login validation."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [[1, 'Test', 'test@example.com', 'testpassword123']]
        mock_connect.return_value.cursor.return_value = mock_cursor
        
        response = client.post('/validateLogin', data={
            'inputEmail': 'test@example.com',
            'inputPassword': 'testpassword123'
        })
        assert response.status_code == 302  # Redirect to userHome
    
    @patch('app.mysql.connect')
    def test_validate_login_invalid_credentials(self, mock_connect, client):
        """Test login with invalid credentials."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []
        mock_connect.return_value.cursor.return_value = mock_cursor
        
        response = client.post('/validateLogin', data={
            'inputEmail': 'invalid@example.com',
            'inputPassword': 'wrongpassword'
        })
        assert response.status_code == 200
        assert b'Wrong Email address or Password' in response.data
    
    @patch('app.mysql.connect')
    def test_validate_login_wrong_password(self, mock_connect, client):
        """Test login with wrong password."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [[1, 'Test', 'test@example.com', 'correctpassword']]
        mock_connect.return_value.cursor.return_value = mock_cursor
        
        response = client.post('/validateLogin', data={
            'inputEmail': 'test@example.com',
            'inputPassword': 'wrongpassword'
        })
        assert response.status_code == 200
        assert b'Wrong Email address or Password' in response.data
    
    @patch('app.mysql.connect')
    def test_add_wish_success(self, mock_connect, client, sample_wish_data):
        """Test successful wish addition."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []
        mock_connect.return_value.cursor.return_value = mock_cursor
        
        with client.session_transaction() as sess:
            sess['user'] = 1
        
        response = client.post('/addWish', data=sample_wish_data)
        assert response.status_code == 302  # Redirect to userHome
    
    @patch('app.mysql.connect')
    def test_add_wish_unauthorized(self, mock_connect, client, sample_wish_data):
        """Test adding wish without authentication."""
        response = client.post('/addWish', data=sample_wish_data)
        assert response.status_code == 200
        assert b'Unauthorized Access' in response.data
    
    @patch('app.mysql.connect')
    def test_get_wish_success(self, mock_connect, client):
        """Test successful retrieval of wishes."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            [1, 'Test Wish 1', 'Description 1', 1, '2023-01-01'],
            [2, 'Test Wish 2', 'Description 2', 1, '2023-01-02']
        ]
        mock_connect.return_value.cursor.return_value = mock_cursor
        
        with client.session_transaction() as sess:
            sess['user'] = 1
        
        response = client.get('/getWish')
        assert response.status_code == 200
        
        data = json.loads(response.data)
        assert len(data) == 2
        assert data[0]['Title'] == 'Test Wish 1'
        assert data[1]['Title'] == 'Test Wish 2'
    
    @patch('app.mysql.connect')
    def test_get_wish_unauthorized(self, mock_connect, client):
        """Test getting wishes without authentication."""
        response = client.get('/getWish')
        assert response.status_code == 200
        assert b'Unauthorized Access' in response.data
    
    def test_user_home_with_session(self, client):
        """Test userHome route with valid session."""
        with client.session_transaction() as sess:
            sess['user'] = 1
        
        response = client.get('/userHome')
        assert response.status_code == 200
        assert b'userHome.html' in response.data or b'User Home' in response.data
