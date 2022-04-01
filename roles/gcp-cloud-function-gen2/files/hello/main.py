from flask import Flask, request

def hello(request):
    name = request.args['name'] if request.args.get('name') else "World"
    return "Hello {}<br/>{}".format(name,request.full_path), 200
