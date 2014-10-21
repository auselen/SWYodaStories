library BinaryReader;

import 'dart:typed_data';
import 'dart:convert';

class BinaryReader {
  int _pos = 0;
  ByteData data;
  
  BinaryReader(this.data);
  
  get pos => _pos;
  
  Uint8List getByteArray(int length) {
    Uint8List a = data.buffer.asUint8List(_pos, length);
    _pos += length;
    return a;
  }
  
  String getTag() {
    return ASCII.decode([data.getInt8(_pos++), data.getInt8(_pos++),
                      data.getInt8(_pos++), data.getInt8(_pos++)]);
  }
  
  int getInt32() {
    int v = data.getInt32(_pos, Endianness.LITTLE_ENDIAN);
    _pos += 4;
    return v;
  }
  
  int getUint32() {
    int v = data.getUint32(_pos, Endianness.LITTLE_ENDIAN);
    _pos += 4;
    return v;
  }
  
  int getInt16() {
    int v = data.getInt16(_pos, Endianness.LITTLE_ENDIAN);
    _pos += 2;
    return v;
  }
  
  int getUint16() {
    int v = data.getUint16(_pos, Endianness.LITTLE_ENDIAN);
    _pos += 2;
    return v;
  }
  
  int getUint8() {
    return data.getUint8(_pos++);
  }

  String getString(int length) {
    String v;
    try {
      v = ASCII.decode(data.buffer.asUint8List(_pos, length));
    } catch(e, stackTrace) {
      v = ASCII.decode(data.buffer.asUint8List(_pos, length), allowInvalid: true);
    }
    _pos += length;
    return v;
  }

  skip(int i) {
    _pos += i;
  }
}
