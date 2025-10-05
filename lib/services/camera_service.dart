import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config_service.dart';

class CameraService {
  static String get _baseUrl => ConfigService.uploadUrl;
  
  final ImagePicker _picker = ImagePicker();

  Future<File?> takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }

  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  Future<String?> uploadPhoto(File imageFile, String jobId, String meterType) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/meter-photo'),
      );
      
      request.fields['jobId'] = jobId;
      request.fields['meterType'] = meterType;
      
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        imageFile.path,
      ));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['photoUrl'];
      } else {
        print('Upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading photo: $e');
      return null;
    }
  }

  Future<List<String>> uploadMultiplePhotos(List<File> imageFiles, String jobId) async {
    List<String> uploadedUrls = [];
    
    for (File imageFile in imageFiles) {
      String? url = await uploadPhoto(imageFile, jobId, 'general');
      if (url != null) {
        uploadedUrls.add(url);
      }
    }
    
    return uploadedUrls;
  }

  Future<File> saveImageToLocal(File imageFile, String fileName) async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      String localPath = '${appDir.path}/$fileName';
      File localFile = await imageFile.copy(localPath);
      return localFile;
    } catch (e) {
      print('Error saving image locally: $e');
      return imageFile;
    }
  }
}
