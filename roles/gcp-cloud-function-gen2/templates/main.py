# originally from CloudFoundry sample: https://github.com/fabianlee/cf-python-maintenancepage/blob/master/maintenance.py
from flask import Flask, render_template, jsonify
import os

# long multi-line string representing HTML file
HTML_STRING = """
<!DOCTYPE html>
<html lang="en">

<head>

  <title>Maintenance</title>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet" crossorigin="anonymous">
  <link rel="icon" href="data:,"/>

<script>
let infuture = new Date()
infuture.setHours(infuture.getHours() + 1);
infuture.setMinutes(infuture.getMinutes() + 30);
</script>

</head>

<body on>

  <div class="px-4 py-5 my-5 text-center">
    <img class="d-block mx-auto mb-4" src="https://cdn-icons-png.flaticon.com/512/498/498970.png" alt="maintenance" height="300"/>
    <h1 class="display-5 fw-bold">System Maintenance</h1>
    <div class="col-lg-6 mx-auto">
	    <p>The system is undergoing maintenance<br/>
	    until <script>document.write(infuture.toUTCString())</script></p>
    </div>
  </div>


</html>
"""

app = Flask(__name__)

@app.route('/maintenance_str')
def return_maintenance_string(request):
    return HTML_STRING, 503

@app.route('/maintenance_file')
def return_maintenance_file(request):
    return render_template(os.path.realpath('maintenance.html')), 503

@app.route('/')
def return_root(request):
    return "MAINTENANCE " + os.getenv("MAINTENANCE_MESSAGE")

@app.route('/json')
def maintenance_json(request):
    return jsonify(type='Exception',status=503,response=os.getenv("MAINTENANCE_MESSAGE")), 200, {'StatusHeader': 'Status: maintenance window'}

@app.route('/<path:dummy>')
def capture_all(request):
    return "trying to reach /" + request + ": " + os.getenv("MAINTENANCE_MESSAGE")

if __name__ == '__main__':
    app.run(host='0.0.0.0')

