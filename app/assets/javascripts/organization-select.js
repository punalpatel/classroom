(function() {
  $('.organizations.new').ready(function() {
    $.get('/organizations')
      .done(function(data) {
        container = document.getElementsByClassName('js-organization-select')[0];
        container.innerHTML = data
      })
    .fail(function(data) {

    });
  })
}).call(this);
