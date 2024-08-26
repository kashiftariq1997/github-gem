$(document).ready(function() {
  var csrfToken = $('meta[name="csrf-token"]').attr('content');
  
  $('#cancel-btn').click(function(event) {
    event.preventDefault();
    $.ajax({
      url: '/logout',
      type: 'DELETE',
      headers: {
        'X-CSRF-Token': csrfToken
      },
      success: function(result) {
        const successAlertDiv = document.createElement('div');
        successAlertDiv.classList.add('alert', 'alert-info', 'alert-dismissible', 'fade', 'show');
        successAlertDiv.setAttribute('role', 'alert');
        successAlertDiv.textContent = 'Logout successfully';
        var alertDiv1 = document.getElementById("alert-auth");
        alertDiv1.appendChild(successAlertDiv);
        setTimeout(function() {
          successAlertDiv.style.display = 'none';
        }, 3000);
        window.location.href = '/';
      },
      error: function(xhr, status, error) {
        const errorAlertDiv = document.createElement('div');
        errorAlertDiv.classList.add('alert', 'alert-info', 'alert-dismissible', 'fade', 'show');
        errorAlertDiv.setAttribute('role', 'alert');
        errorAlertDiv.textContent = 'Logout Failed';
        var alertDiv1 = document.getElementById("alert-auth");
        alertDiv1.appendChild(errorAlertDiv);
        setTimeout(function() {
          errorAlertDiv.style.display = 'none';
        }, 3000);
      }
    });
  });
});
