import struct
import itertools

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
	return matrix

def matrix_mulitply(matrix, scalar):
	return [[v * scalar for v in row] for row in matrix]


print(deserialize(serialize([[1, 2, 3], [4, 5, 6], [7, 8, 9]])))