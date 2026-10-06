import 'dart:io';
import 'dart:convert';

void main() {
  // The base64 code for a 1x1 transparent PNG
  const String base64Image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=";
  
  try {
    // 1. Decode the image
    final bytes = base64Decode(base64Image);
    
    // 2. Create the file and any missing folders
    final file = File('assets/images/transparent.png');
    file.createSync(recursive: true);
    
    // 3. Write the image to the file
    file.writeAsBytesSync(bytes);
    
    print('SUCCESS! transparent.png has been created in assets/images/');
  } catch (e) {
    print('❌ ERROR: $e');
  }
}