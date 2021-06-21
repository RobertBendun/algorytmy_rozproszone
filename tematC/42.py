import itertools
import random
import struct
import sys
import zmq

Header_Format = "QQ"
Header_Length = 2 * 8

def serialize(data):
	w, h = len(data), len(data[0])
	header = struct.pack(Header_Format, w, h)
	return header + b"".join((struct.pack("d", v) for row in data for v in row))

def deserialize(data):
	w, h = struct.unpack(Header_Format, data[:Header_Length])	
	matrix = []
	for i, v in zip(itertools.count(0), struct.iter_unpack("d", data[Header_Length : w * h * 8 + Header_Length])):
		if i % w == 0:
			matrix.append([])
		matrix[-1].append(v[0])
	return matrix, data[w * h * 8 + Header_Length:]

def encode(matrices):
	header = struct.pack("Q", len(matrices))
	return header + b''.join(serialize(matrix) for matrix in matrices)

def decode(data):
	n, data = struct.unpack("Q", data[:8]), data[8:]

	matricies = []
	for _ in range(0, n[0]):
		matrix, data = deserialize(data)
		matricies.append(matrix)

	return matricies


def matrix_mulitply(matrix, scalar):
	return [[v * scalar for v in row] for row in matrix]

def client():
	context = zmq.Context()
	socket = context.socket(zmq.REQ)
	socket.connect("tcp://localhost:5050")

	w = random.randint(1, 10)
	h = random.randint(1, 10)

	matricies = []

	for _ in range(random.randint(0, 5)):
		matricies.append([])
		for _ in range(0, w):
			matricies[-1].append([])
			for _ in range(0, h):
				matricies[-1][-1].append(random.randint(0, 9))

	print(matricies)
	socket.send(encode(matricies))
	for x in decode(socket.recv()):
		print(x)

def server():
	context = zmq.Context()
	socket = context.socket(zmq.REP)
	socket.bind("tcp://*:5050")

	while True:
		message = socket.recv()
		matricies = decode(message)
		socket.send(encode(list(
			matrix_mulitply(matrix, 2)
			for matrix in matricies
		)))


if len(sys.argv) == 2:
	if sys.argv[1] == 'server':
		server()
		exit()
	
	if sys.argv[1] == 'client':
		client()
		exit()

print(f"{sys.argv} client|server")
exit(1)
