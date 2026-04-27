import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/app_models.dart';

class ClassListViewModel extends ChangeNotifier {

  final String _baseUrl=ApiConstants.baseUrl;
  static const int _maxStudentsPerClass=75;

  bool _isLoading=false;
  bool get isLoading=>_isLoading;

  List<AppClassModel> _availableClasses=[];
  List<AppClassModel> get availableClasses=>_availableClasses;

  final Map<String,int> _acceptedCounts={};
  final Map<String,bool> _countKnown={};

  // attendance open map
  final Map<String,bool> _attendanceOpenMap={};

  String _openedAttendanceClassId='';

  String get openedAttendanceClassId =>
      _openedAttendanceClassId;

  bool isAttendanceOpen(String classId){
    return _attendanceOpenMap[classId]==true;
  }

  bool canCheckIn(String classId){
    return classId==_openedAttendanceClassId;
  }

  String _lastActionMessage='';
  String get lastActionMessage=>_lastActionMessage;

  int _getMyStudentId(String token){
    try{
      final payload=token.split('.')[1];

      final decoded=jsonDecode(
          utf8.decode(
              base64Url.decode(
                  base64Url.normalize(payload)
              )
          )
      );

      return int.parse(decoded["sub"].toString());

    }catch(_){
      return 0;
    }
  }

  List<dynamic> _safeList(dynamic data){

    if(data is List){
      return data;
    }

    if(data is Map){

      if(data["content"] is List){
        return data["content"];
      }

      if(data["data"] is List){
        return data["data"];
      }

      if(data["data"] is Map &&
          data["data"]["content"] is List){
        return data["data"]["content"];
      }

    }

    return [];
  }

  int? _parseInt(dynamic v){

    if(v==null) return null;

    if(v is int) return v;

    if(v is double) return v.toInt();

    return int.tryParse(v.toString());

  }

  int? _extractAcceptedCount(
      Map<String,dynamic> item){

    const keys=[
      'acceptedStudentCount',
      'acceptedCount',
      'studentCount',
      'currentStudentCount',
      'memberCount'
    ];

    for(final key in keys){

      final value=_parseInt(item[key]);

      if(value!=null){
        return value;
      }

    }

    return null;
  }

  int getAcceptedCount(
      String classId
      ) =>
      _acceptedCounts[classId] ?? 0;

  bool hasKnownCount(
      String classId
      ) =>
      _countKnown[classId]==true;

  bool isClassFull(
      String classId
      ){

    if(!hasKnownCount(classId)){
      return false;
    }

    return getAcceptedCount(classId)
        >=_maxStudentsPerClass;

  }

  String getCapacityText(
      String classId
      ){

    if(hasKnownCount(classId)){
      return
        "Sĩ số: ${getAcceptedCount(classId)}/$_maxStudentsPerClass";
    }

    return
      "Tối đa $_maxStudentsPerClass sinh viên";

  }

  Future<void> fetchAvailableClasses() async{

    _isLoading=true;
    notifyListeners();

    try{

      final prefs=
      await SharedPreferences.getInstance();

      final token=
      prefs.getString("access_token");

      if(token==null || token.isEmpty){
        throw Exception("Chưa đăng nhập");
      }

      final myStudentId=
      _getMyStudentId(token);

      // lớp đã đăng ký
      final myRegResponse=
      await http.get(
          Uri.parse(
              "$_baseUrl/class-registrations/$myStudentId/classes?page=0&size=100"
          ),
          headers:{
            "Authorization":"Bearer $token"
          }
      );

      final registeredIds=<String>{};

      if(myRegResponse.statusCode==200){

        final decoded=jsonDecode(
            utf8.decode(
                myRegResponse.bodyBytes
            )
        );

        final List list=
        _safeList(decoded);

        for(var item in list){

          final id=
              item["classId"]?.toString()
                  ?? item["classroomId"]?.toString()
                  ?? '0';

          final status=
              item["status"]
                  ?.toString()
                  .toUpperCase()
                  .trim()
                  ?? "PENDING";

          if(status=="PENDING" ||
              status=="ACCEPTED"){
            registeredIds.add(id);
          }

        }

      }

      // lấy classes
      final response=
      await http.get(
          Uri.parse(
              "$_baseUrl/classrooms?page=0&size=100"
          ),
          headers:{
            "Authorization":"Bearer $token"
          }
      );

      _availableClasses=[];
      _acceptedCounts.clear();
      _countKnown.clear();

      if(response.statusCode!=200){
        throw Exception("Không tải được lớp");
      }

      final decoded=jsonDecode(
          utf8.decode(response.bodyBytes)
      );

      final List list=
      _safeList(decoded);

      _availableClasses=list.where((item){

        final id=
            item["id"]?.toString()
                ?? item["classId"]?.toString()
                ?? '0';

        return !registeredIds.contains(id);

      }).map((item){

        final map=
        Map<String,dynamic>.from(item);

        final classId=
            map["id"]?.toString()
                ?? map["classId"]?.toString()
                ?? '0';

        final count=
        _extractAcceptedCount(map);

        if(count!=null){
          _acceptedCounts[classId]=count;
          _countKnown[classId]=true;
        }

        return AppClassModel(
            id: classId,
            teacherId:
            map["teacherId"]?.toString()??'0',
            className:
            map["title"] ?? '',
            description:
            map["description"] ?? '',
            teacherName:
            map["teacherName"] ?? '',
            startTime:
            map["startDate"]?.toString()??'',
            endTime:
            map["endDate"]?.toString()??''
        );

      }).toList();

      //==============================
      // lấy session mở (chỉ 1 duy nhất)
      //==============================

      _openedAttendanceClassId='';
      _attendanceOpenMap.clear();

      final sessionRes=
      await http.get(
          Uri.parse("$_baseUrl/sessions"),
          headers:{
            "Authorization":"Bearer $token"
          }
      );

      if(sessionRes.statusCode==200){

        final sessionData=jsonDecode(
            utf8.decode(
                sessionRes.bodyBytes
            )
        );

        final List sessions=
        _safeList(sessionData);

        for(var s in sessions){

          final status=
          s["status"]
              ?.toString()
              .toUpperCase();

          if(status=="OPEN"){

            final classId=
                s["classId"]?.toString()
                    ?? s["classroomId"]?.toString()
                    ?? '';

            if(classId.isNotEmpty){

              _openedAttendanceClassId=
                  classId;

              _attendanceOpenMap[classId]=true;

              break; // duy nhất 1 lớp
            }

          }

        }

      }

      // lớp mở lên đầu
      _availableClasses.sort((a,b){

        if(a.id==_openedAttendanceClassId){
          return -1;
        }

        if(b.id==_openedAttendanceClassId){
          return 1;
        }

        final aFull=isClassFull(a.id);
        final bFull=isClassFull(b.id);

        if(aFull==bFull){
          return 0;
        }

        return aFull ? 1 : -1;

      });

    }
    catch(e){

      _lastActionMessage=
          e.toString()
              .replaceAll(
              "Exception: ",
              ""
          );

      _availableClasses=[];

    }
    finally{
      _isLoading=false;
      notifyListeners();
    }

  }

  Future<bool> registerClass(
      String classId
      ) async{

    try{

      _isLoading=true;
      notifyListeners();

      if(isClassFull(classId)){
        _lastActionMessage=
        "Lớp đã đầy";
        return false;
      }

      final prefs=
      await SharedPreferences.getInstance();

      final token=
      prefs.getString(
          "access_token"
      );

      if(token==null){
        throw Exception(
            "Chưa đăng nhập"
        );
      }

      final studentId=
      _getMyStudentId(token);

      final body={
        "classId":int.parse(classId),
        "studentId":studentId
      };

      final response=
      await http.post(
          Uri.parse(
              "$_baseUrl/class-registrations"
          ),
          headers:{
            "Authorization":"Bearer $token",
            "Content-Type":"application/json"
          },
          body:jsonEncode(body)
      );

      final success=
          response.statusCode==200 ||
              response.statusCode==201;

      if(success){

        _lastActionMessage=
        "Đăng ký thành công";

        _availableClasses.removeWhere(
                (c)=>c.id==classId
        );

      }else{
        _lastActionMessage=
        "Đăng ký thất bại";
      }

      return success;

    }
    catch(e){

      _lastActionMessage=
          e.toString();

      return false;

    }
    finally{

      _isLoading=false;
      notifyListeners();

    }

  }

}