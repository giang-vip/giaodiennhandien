import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/app_models.dart';
import '../../../core/constants/api_constants.dart';

class ClassManagementViewModel extends ChangeNotifier {

  final String _baseUrl = ApiConstants.baseUrl;

  bool _isLoading=false;
  bool get isLoading=>_isLoading;

  List<AppClassModel> _realClasses=[];
  List<AppClassModel> get realClasses=>_realClasses;

  final Map<String,Map<String,dynamic>> _activeSessionData={};
  final Map<String,Timer> _attendanceTimers={};
  final Set<String> _closingClassIds={};

  //================ JWT ====================

  Map<String,dynamic> _decodeJwt(String token){
    try{
      final payload=token.split('.')[1];
      return jsonDecode(
          utf8.decode(
              base64Url.decode(
                  base64Url.normalize(payload)
              )
          )
      );
    }catch(e){
      return {};
    }
  }

  Future<bool> _isTokenValid(String token) async{
    final prefs=await SharedPreferences.getInstance();

    final jwt=_decodeJwt(token);

    if(jwt['type']!='access'){
      await prefs.clear();
      return false;
    }

    final exp=jwt['exp'];

    if(exp!=null){
      final now=DateTime.now().millisecondsSinceEpoch~/1000;

      if(now>=exp){
        await prefs.clear();
        return false;
      }
    }

    return true;
  }

  List _safeList(dynamic data){
    try{
      if(data is List) return data;

      if(data is Map){

        if(data["data"]!=null){

          if(data["data"] is Map &&
              data["data"]["content"]!=null){
            return data["data"]["content"];
          }

          if(data["data"] is List){
            return data["data"];
          }

        }

        if(data["content"]!=null){
          return data["content"];
        }

      }

    }catch(_){}

    return [];
  }

  String _normalizeText(String input){
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'),' ');
  }

  DateTime? _parseDateTime(dynamic value){
    if(value==null) return null;

    final text=value.toString().trim();

    if(text.isEmpty) return null;

    return DateTime.tryParse(text);
  }

  bool _isOpenStatus(dynamic status){
    final s=status?.toString().toUpperCase().trim() ?? '';
    return s=="OPEN" ||
        s=="1" ||
        s=="ACTIVE" ||
        s=="ONGOING";
  }

  int _calculateAttendanceMinutes(
      dynamic start,
      dynamic end
      ){

    final s=_parseDateTime(start);
    final e=_parseDateTime(end);

    if(s==null || e==null) return 0;

    final m=e.difference(s).inMinutes;

    return m>0 ? m : 0;
  }

  void _cancelTimer(String classId){
    _attendanceTimers[classId]?.cancel();
    _attendanceTimers.remove(classId);
  }

  void _cancelAllTimers(){
    for(final t in _attendanceTimers.values){
      t.cancel();
    }

    _attendanceTimers.clear();
  }

  Future<Map<String,String>> _getHeaders() async{

    final prefs=await SharedPreferences.getInstance();

    final token=prefs.getString("access_token");

    if(token==null || token.isEmpty){
      throw Exception("Không tìm thấy token");
    }

    return {
      "Authorization":"Bearer $token",
      "Content-Type":"application/json"
    };

  }

  //============== SORT lớp mở lên đầu ===============

  void _sortClasses(){
    _realClasses.sort((a,b){

      if(a.isAttendanceOpen && !b.isAttendanceOpen){
        return -1;
      }

      if(!a.isAttendanceOpen && b.isAttendanceOpen){
        return 1;
      }

      return 0;

    });
  }

  //===================================================

  Future<void> fetchClasses() async{

    _isLoading=true;
    notifyListeners();

    try{

      final prefs=await SharedPreferences.getInstance();

      final token=prefs.getString("access_token");

      if(token==null || token.isEmpty){
        _realClasses=[];
        return;
      }

      final valid=await _isTokenValid(token);

      if(!valid){
        _realClasses=[];
        return;
      }

      final jwt=_decodeJwt(token);
      final myTeacherId=jwt["sub"]?.toString() ?? "";

      final headers={
        "Authorization":"Bearer $token",
        "Content-Type":"application/json"
      };

      _cancelAllTimers();
      _activeSessionData.clear();

      final classRes=await http.get(
          Uri.parse("$_baseUrl/classrooms?page=0&size=50"),
          headers: headers
      );

      if(classRes.statusCode!=200){
        _realClasses=[];
        return;
      }

      final classData=jsonDecode(
          utf8.decode(classRes.bodyBytes)
      );

      final List classList=_safeList(classData);

      final mapped=classList.map((item){

        final classId=(item["id"]??item["classId"]).toString();

        final teacherId=
            item["teacherId"]?.toString()
                ?? item["teacher"]?["id"]?.toString()
                ?? '';

        final locationIds=item["locationIds"];

        final localRoomId=
        prefs.getString("class_${classId}_room");

        String? roomId;

        if(localRoomId!=null &&
            localRoomId.isNotEmpty){
          roomId=localRoomId;
        }
        else if(locationIds is List &&
            locationIds.isNotEmpty){
          roomId=locationIds.first.toString();
        }

        final radius=
        prefs.getDouble("class_${classId}_radius");

        return AppClassModel(
            id: classId,
            teacherId: teacherId,
            className: item["title"] ?? '',
            description: item["description"] ?? '',
            teacherName: item["teacherName"] ?? '',
            startTime: item["startDate"]?.toString() ?? '',
            endTime: item["endDate"]?.toString() ?? '',
            isAttendanceOpen: false,
            attendanceDuration:0,
            roomId: roomId,
            radius: radius
        );

      }).toList();

      _realClasses=
          mapped.where(
                  (c)=>c.teacherId.toString()==myTeacherId
          ).toList();

      final sessionRes=await http.get(
          Uri.parse("$_baseUrl/sessions"),
          headers: headers
      );

      if(sessionRes.statusCode==200){

        final sessionData=jsonDecode(
            utf8.decode(sessionRes.bodyBytes)
        );

        final List sessionList=
        _safeList(sessionData);

        for(var s in sessionList){

          if(!_isOpenStatus(s["status"])){
            continue;
          }

          String? classId=
              s["classroomId"]?.toString()
                  ?? s["classId"]?.toString();

          if(classId==null) continue;

          _activeSessionData[classId]={
            "sessionId":s["sessionId"]??s["id"],
            "locationId":s["locationId"],
            "title":s["title"],
            "startTime":s["startTime"],
            "endTime":s["endTime"]
          };

          final idx=
          _realClasses.indexWhere(
                  (c)=>c.id==classId
          );

          if(idx!=-1){

            _realClasses[idx]=
                _realClasses[idx].copyWith(
                    isAttendanceOpen:true,
                    attendanceDuration:
                    _calculateAttendanceMinutes(
                        s["startTime"],
                        s["endTime"]
                    ),
                    attendanceStartTime:
                    s["startTime"]?.toString(),
                    attendanceEndTime:
                    s["endTime"]?.toString()
                );

            _scheduleAutoClose(classId);

          }

        }

      }

      _sortClasses();

    }
    catch(e){
      print(e);
      _realClasses=[];
    }
    finally{
      _isLoading=false;
      notifyListeners();
    }

  }

  void _scheduleAutoClose(String classId){

    _cancelTimer(classId);

    final c=_realClasses.cast<AppClassModel?>().firstWhere(
            (x)=>x?.id==classId,
        orElse: ()=>null
    );

    if(c==null) return;

    final end=c.attendanceEndDateTime;

    if(end==null) return;

    final remain=
    end.difference(DateTime.now());

    if(remain.inSeconds<=0){
      _closeExpiredSession(classId);
      return;
    }

    _attendanceTimers[classId]=
        Timer(remain,() async{
          await _closeExpiredSession(classId);
        });

  }

  Future<void> _closeExpiredSession(
      String classId
      ) async{

    if(_closingClassIds.contains(classId)) return;

    _closingClassIds.add(classId);

    try{

      final session=_activeSessionData[classId];
      if(session==null) return;

      final idx=
      _realClasses.indexWhere((c)=>c.id==classId);

      if(idx==-1) return;

      await _closeSessionInternal(
          classId: classId,
          current: _realClasses[idx],
          sessionData: session
      );

    }finally{
      _closingClassIds.remove(classId);
    }

  }

  //============ chỉ cho mở 1 lớp duy nhất ============

  bool _hasOtherOpenedClass(String currentClassId){

    return _realClasses.any(
            (c)=>
        c.id!=currentClassId &&
            c.isAttendanceOpen
    );

  }

  //===================================================

  Future<void> toggleAttendance(
      String classId,
      int minutes
      ) async{

    final index=
    _realClasses.indexWhere(
            (c)=>c.id==classId
    );

    if(index==-1){
      throw Exception("Không tìm thấy lớp");
    }

    final current=_realClasses[index];

    // chặn mở nhiều lớp cùng lúc
    if(!current.isAttendanceOpen &&
        _hasOtherOpenedClass(classId)){
      throw Exception(
          "Bạn đang mở điểm danh cho lớp khác. Hãy đóng phiên hiện tại trước."
      );
    }

    final headers=await _getHeaders();

    if(!current.isAttendanceOpen){

      final now=DateTime.now();
      final end=
      now.add(Duration(minutes: minutes));

      final locationId=
      int.tryParse(current.roomId ?? '');

      if(locationId==null || locationId<=0){
        throw Exception(
            "Hãy Set Location trước."
        );
      }

      final body={
        "title":"Attendance - ${current.className}",
        "startTime":now.toIso8601String(),
        "endTime":end.toIso8601String(),
        "status":"OPEN",
        "classId":int.parse(classId),
        "locationId":locationId
      };

      final res=await http.post(
          Uri.parse("$_baseUrl/sessions"),
          headers: headers,
          body: jsonEncode(body)
      );

      if(res.statusCode==200 ||
          res.statusCode==201){

        _realClasses[index]=
            current.copyWith(
                isAttendanceOpen:true,
                attendanceDuration:minutes,
                attendanceStartTime:
                now.toIso8601String(),
                attendanceEndTime:
                end.toIso8601String()
            );

        _sortClasses();

        notifyListeners();

        _scheduleAutoClose(classId);

        await fetchClasses();

      }else{
        throw Exception(
            "Mở điểm danh thất bại"
        );
      }

    }
    else{

      final session=
      _activeSessionData[classId];

      if(session==null){
        throw Exception(
            "Không tìm thấy session đang mở"
        );
      }

      await _closeSessionInternal(
          classId: classId,
          current: current,
          sessionData: session
      );

    }

  }

  Future<void> _closeSessionInternal({
    required String classId,
    required AppClassModel current,
    required Map<String,dynamic> sessionData
  }) async{

    final headers=await _getHeaders();

    final sessionId=sessionData["sessionId"];

    final body={
      "title":sessionData["title"],
      "startTime":sessionData["startTime"],
      "endTime":DateTime.now().toIso8601String(),
      "status":"CLOSED",
      "classId":int.parse(classId),
      "locationId":int.parse(
          current.roomId.toString()
      )
    };

    final res=await http.put(
        Uri.parse(
            "$_baseUrl/sessions/$sessionId"
        ),
        headers: headers,
        body: jsonEncode(body)
    );

    if(res.statusCode==200 ||
        res.statusCode==201){

      _cancelTimer(classId);

      _activeSessionData.remove(classId);

      final idx=
      _realClasses.indexWhere(
              (c)=>c.id==classId
      );

      if(idx!=-1){

        _realClasses[idx]=
            _realClasses[idx].copyWith(
                isAttendanceOpen:false,
                attendanceDuration:0,
                attendanceStartTime:null,
                attendanceEndTime:null
            );

        _sortClasses();

        notifyListeners();
      }

      await fetchClasses();

    }else{
      throw Exception(
          "Đóng điểm danh thất bại"
      );
    }

  }

  Future<void> deleteClass(String classId) async{

    final headers=await _getHeaders();

    final res=await http.delete(
        Uri.parse(
            "$_baseUrl/classrooms/$classId"
        ),
        headers: headers
    );

    if(res.statusCode==200 ||
        res.statusCode==204){

      _realClasses.removeWhere(
              (c)=>c.id==classId
      );

      _cancelTimer(classId);

      _activeSessionData.remove(classId);

      notifyListeners();

    }else{
      throw Exception("Xóa thất bại");
    }

  }

  Future<void> updateClass(
      AppClassModel updated
      ) async{

    final idx=
    _realClasses.indexWhere(
            (c)=>c.id==updated.id
    );

    if(idx!=-1){
      _realClasses[idx]=updated;
      notifyListeners();
    }

    await fetchClasses();

  }

  String getRemainingTimeText(
      AppClassModel c
      ){

    final remain=
        c.remainingAttendanceTime;

    if(!c.isAttendanceOpen){
      return "Đã đóng";
    }

    if(remain==null){
      return "Không rõ";
    }

    if(remain==Duration.zero){
      return "Đã hết giờ";
    }

    final h=remain.inHours;
    final m=remain.inMinutes.remainder(60);
    final s=remain.inSeconds.remainder(60);

    if(h>0){
      return "${h}h ${m}m ${s}s";
    }

    return "${m}m ${s}s";

  }

  @override
  void dispose(){
    _cancelAllTimers();
    super.dispose();
  }

}