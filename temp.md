```html
<form>
  <fieldset>
    <legend>Form 1</legend>
    <label for="name">Name:</label><br>
    <input type="text" id="name" name="name"><br>
    <label for="email">Email:</label><br>
    <input type="email" id="email" name="email"><br>
  </fieldset>

  <fieldset>
    <legend>Form 2</legend>
    <label for="name2">Name:</label><br>
    <input type="text" id="name2" name="name2" value="{{ form1.name }}"><br>
    <label for="email2">Email:</label><br>
    <input type="email" id="email2" name="email2" value="{{ form1.email }}"><br>
  </fieldset>
</form>
```
