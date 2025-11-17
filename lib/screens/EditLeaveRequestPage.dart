import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditLeaveRequestPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> initialData;
  final bool isAdmin;

  const EditLeaveRequestPage({
    Key? key,
    required this.requestId,
    required this.initialData,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  State<EditLeaveRequestPage> createState() => _EditLeaveRequestPageState();
}

class _EditLeaveRequestPageState extends State<EditLeaveRequestPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  late DateTime startDate;
  late DateTime endDate;
  late String leaveType;
  late String reason;
  late String status;
  bool _isSaving = false;

  // Design constants
  static const Color primaryColor = Color(0xFF4361EE);
  static const Color errorColor = Color(0xFFE63946);
  static const Color backgroundLight = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    startDate = (widget.initialData['startDate'] as Timestamp).toDate();
    endDate = (widget.initialData['endDate'] as Timestamp).toDate();
    leaveType = widget.initialData['typeConge'] ?? '';
    reason = widget.initialData['reason'] ?? '';
    status = (widget.initialData['status'] ?? 'en attente').toString();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? startDate : endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          if (endDate.isBefore(startDate)) {
            endDate = startDate;
          }
        } else {
          endDate = picked;
          if (endDate.isBefore(startDate)) {
            startDate = endDate;
          }
        }
      });
    }
  }

  Future<void> _deleteRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Supprimer la demande"),
            content: const Text(
              "Êtes-vous sûr de vouloir supprimer cette demande de congé?",
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: errorColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Supprimer",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _firestore
            .collection('leave_requests')
            .doc(widget.requestId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Demande supprimée avec succès'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: $e'),
              backgroundColor: errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updateData = {
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'typeConge': leaveType,
        'reason': reason.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (widget.isAdmin) {
        updateData['status'] = status;
      }

      await _firestore
          .collection('leave_requests')
          .doc(widget.requestId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Demande mise à jour avec succès'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approuvé':
        return Colors.green;
      case 'rejeté':
        return errorColor;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: const Text('Modifier la demande'),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteRequest,
            tooltip: 'Supprimer la demande',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDatePickerTile(
                        title: 'Date de début',
                        date: startDate,
                        onTap: () => _pickDate(isStart: true),
                      ),
                      const Divider(height: 24),
                      _buildDatePickerTile(
                        title: 'Date de fin',
                        date: endDate,
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: leaveType,
                        decoration: InputDecoration(
                          labelText: 'Type de congé',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: backgroundLight,
                          prefixIcon: const Icon(Icons.work_outline),
                        ),
                        style: const TextStyle(fontSize: 16),
                        validator:
                            (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Veuillez saisir le type'
                                    : null,
                        onChanged: (val) => leaveType = val,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: reason,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Justification',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: backgroundLight,
                          prefixIcon: const Icon(Icons.note_outlined),
                        ),
                        style: const TextStyle(fontSize: 16),
                        onChanged: (val) => reason = val,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child:
                      widget.isAdmin
                          ? DropdownButtonFormField<String>(
                            value: status,
                            decoration: InputDecoration(
                              labelText: 'Statut',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: backgroundLight,
                              prefixIcon: const Icon(Icons.stairs_outlined),
                            ),
                            items:
                                ['en attente', 'approuvé', 'rejeté'].map((
                                  status,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => status = val);
                            },
                          )
                          : ListTile(
                            leading: const Icon(Icons.stairs_outlined),
                            title: const Text('Statut actuel'),
                            subtitle: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child:
                          _isSaving
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                              : const Text(
                                'ENREGISTRER',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerTile({
    required String title,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: primaryColor.withOpacity(0.8),
              size: 24,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_outlined,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
