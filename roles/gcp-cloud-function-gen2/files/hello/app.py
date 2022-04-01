import flask
import main


app = flask.Flask(__name__)

@app.route('/', defaults={'path':''})
@app.route('/<path:path>')
def index(path):
    return main.hello(flask.request)

if __name__ == '__main__':
    app.run()

