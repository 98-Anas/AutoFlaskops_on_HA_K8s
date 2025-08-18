import pytest
import json
from unittest.mock import patch, MagicMock

class TestAuthentication:
    """Test authentication and session management."""
    
    def test_session_management(self, client):
        """Test session management across requests."""
        with client.session_transaction() as sess:
            sess['user'] = 123
        
        response = client.get('/userHome')
        assert response.status_code == 200
        
        # Test logout clears session
        client.get('/logout')
        
        response = client.get('/userHome')
        assert response.status_code == 200
        assert b'Unauthorized Access' in response.data
    
    def test_session_timeout_handling(self, client):
        """Test handling of expired or invalid sessions."""
        # Access protected route without session
        response = client.get('/userHome')
        assert response.status_code == 200
        assert b'Unauthorized Access' in response.data
    
    @patch('app.mysql.connect')
    def test_login_flow_complete(self, mock_connect, client):
        """Test complete login flow from signin to user home."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [[1, 'Test User', 'test@example.com', 'password123']]
        mock_connect.return_value.cursor.return_value = mock_cursor
        
        # Test login
        response = client.post('/validateLogin', data={
            'inputEmail': 'test@example.com',
            'inputPassword': 'password123'
        })
        assert response.status_code == 302
        
        # Test accessing protected route after login
        response = client.get('/userHome')
        assert response.status_code == 200
    
    def test_password_validation_edge_cases(self, client):
        """Test password validation edge cases."""
        test_cases = [
            {'inputEmail': '', 'inputPassword': ''},
            {'inputEmail': 'invalid-email', 'inputPassword': 'short'},
            {'inputEmail': 'valid@email.com', 'inputPassword': ''},
        ]
        
        for test_case in test_cases:
            response = client.post('/validateLogin', data=test_case)
            assert response.status_code == 200
            assert b'Wrong Email address or Password' in response.data or b'error' in response.data

class TestDatabaseOperations:
    """Test database operations and stored procedures."""
    
    @patch('app.mysql.connect')
    def test_database_connection(self, mock_connect, client):
        """Test database connection establishment."""
        mock_connection = MagicMock()
        mock_connect.return_value = mock_connection
        
        response = client.get('/')
        # Connection should be established for any route
        assert mock_connect.called
    
    @patch('app.mysql.connect')
    def test_stored_procedure_calls(self, mock_connect, client, sample_user_data):
        """Test stored procedure calls with parameters."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []
        mock_connect.return_value.cursor.return_value = mock_cursor
        
        response = client.post('/signUp', data=sample_user_data)
        
        # Verify stored procedure was called with correct parameters
        mock_cursor.callproc.assert_called_with(
            'sp_createUser',
            ('Test User', 'test@example.com', 'testpassword123')
        )
    
    @patch('app.mysql.connect')
    def test_transaction_commit_on_success(self, mock_connect, client, sample_user_data):
        """Test transaction commit on successful operations."""
        mock_connection = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []
        
        mock_connect.return_value = mock_connection
        mock_connection.cursor.return_value = mock_cursor
        
        response = client.post('/signUp', data=sample_user_data)
        
        mock_connection.commit.assert_called_once()
    
    @patch('app.mysql.connect')
    def test_transaction_rollback_on_error(self, mock_connect, client, sample_user_data):
        """Test transaction rollback on database errors."""
        mock_connection = MagicMock()
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [('Database error',)]
        
        mock_connect.return_value = mock_connection
        mock_connection.cursor.return_value = mock_cursor
        
        response = client.post('/signUp', data=sample_user_data)
        
        mock_connection.commit.assert_not_called()

class TestErrorHandling:
    """Test error handling and edge cases."""
    
    def test_404_handling(self, client):
        """Test 404 error handling."""
        response = client.get('/nonexistent-route')
        assert response.status_code == 404
    
    @patch('app.mysql.connect')
    def test_database_connection_error(self, mock_connect, client):
        """Test handling of database connection errors."""
        mock_connect.side_effect = Exception("Database connection failed")
        
        response = client.post('/signUp', data={
            'inputName': 'Test',
            'inputEmail': 'test@example.com',
            'inputPassword': 'password'
        })
        assert response.status_code == 200
        assert b'error' in response.data
    
    @patch('app.mysql.connect')
    def test_stored_procedure_error(self, mock_connect, client):
        """Test handling of stored procedure errors."""
        mock_cursor = MagicMock()
        mock_cursor.callproc.side_effect = Exception("Procedure error")
        mock_connect.return_value.cursor.return_value = mock_cursor
        
        response = client.post('/signUp', data={
            'inputName': 'Test',
            'inputEmail': 'test@example.com',
            'inputPassword': 'password'
        })
        assert response.status_code == 200
        assert b'error' in response.data
    
    def test_json_response_format(self, client):
        """Test JSON response format for API endpoints."""
        # Test JSON response format
        response = client.get('/getWish')
        if response.status_code == 200:
            try:
                json.loads(response.data)
                assert True
            except json.JSONDecodeError:
                assert False, "Response is not valid JSON"
