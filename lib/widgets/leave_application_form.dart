import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class LeaveApplicationForm extends StatefulWidget {
  @override
  _LeaveApplicationFormState createState() => _LeaveApplicationFormState();
}

class _LeaveApplicationFormState extends State<LeaveApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else _endDate = picked;
      });
    }
  }

  Future<void> _submitLeave() async {
    if (!_formKey.currentState!.validate() || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields and select dates.')),
      );
      return;
    }

    setState(() { _isSubmitting = true; });

    try {
      await Supabase.instance.client.from('leave_requests').insert({
        'employee_name': _nameController.text,
        'role': _roleController.text,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'reason': _reasonController.text,
        'status': 'Pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave request submitted successfully.'), backgroundColor: Colors.green),
      );
      
      _nameController.clear();
      _roleController.clear();
      _reasonController.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
      });
      
      Navigator.pop(context); // Close the form/modal
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() { _isSubmitting = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leave Application', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Employee Name',
                labelStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _roleController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Role',
                labelStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _selectDate(context, true),
                    icon: Icon(Icons.calendar_today, size: 16),
                    label: Text(_startDate == null ? 'Start Date' : DateFormat('yyyy-MM-dd').format(_startDate!)),
                    style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F172A), foregroundColor: Colors.white),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _selectDate(context, false),
                    icon: Icon(Icons.calendar_today, size: 16),
                    label: Text(_endDate == null ? 'End Date' : DateFormat('yyyy-MM-dd').format(_endDate!)),
                    style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F172A), foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              style: TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason',
                labelStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitLeave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmitting
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Submit Leave Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
