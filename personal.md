
```rust
<!-- template.stpl -->
<html>
<head><title>Page {{ current_page }}</title></head>
<body>
  <!-- Display items for the current page -->
  <ul>
    {% for item in page_data %}
      <li>{{ item }}</li>
    {% endfor %}
  </ul>

  <!-- Pagination form -->
  <form action="/paginate" method="post">
    <input type="hidden" name="page" value="{{ current_page - 1 }}">
    <button type="submit" {% if current_page == 1 %}disabled{% endif %}>Previous</button>
  </form>

  <form action="/paginate" method="post">
    <input type="hidden" name="page" value="{{ current_page + 1 }}">
    <button type="submit" {% if current_page == total_pages %}disabled{% endif %}>Next</button>
  </form>
</body>
</html>


<!-- template.stpl -->
<html>
<head><title>Page {{ current_page }}</title></head>
<body>
  <!-- Display items for the current page -->
  <ul>
    {% for item in page_data %}
      <li>{{ item }}</li>
    {% endfor %}
  </ul>

  <!-- Pagination links -->
  {% if current_page > 1 %}
    <a href="/?page={{ current_page - 1 }}">Previous</a>
  {% endif %}

  {% if current_page < total_pages %}
    <a href="/?page={{ current_page + 1 }}">Next</a>
  {% endif %}
</body>
</html>
```
