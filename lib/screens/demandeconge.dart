import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class DemandeCongePage extends StatefulWidget {
  const DemandeCongePage({super.key, required String typeConge});

  @override
  State<DemandeCongePage> createState() => _DemandeCongePageState();
}

class _DemandeCongePageState extends State<DemandeCongePage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _hireDate;
  String? _selectedTypeConge;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();
  bool _isSubmitting = false;
  double _leaveDaysUsed = 0.0;
  double _currentYearBalance = 0.0;
  double _previousYearBalance = 0.0;

  // Leave types
  final List<Map<String, dynamic>> _leaveTypes = [
    {
      'label': 'Congé de repos',
      'category': 'Payé',
      'icon': Icons.hotel,
    },
    {
      'label': 'Congé Sans Solde',
      'category': 'Non payé',
      'icon': Icons.money_off,
    },
    {
      'label': 'Congé Maladie',
      'category': 'Non payé',
      'icon': Icons.medical_services,
    },
  ];

  // UI Constants
  static const _primaryColor = Color(0xFF4F46E5);
  static const _secondaryColor = Color(0xFF6366F1);
  static const _backgroundColor = Color(0xFFF9FAFB);
  static const _cardColor = Colors.white;
  static const _errorColor = Color(0xFFEF4444);
  static const _successColor = Color(0xFF10B981);
  static const _textColor = Color(0xFF111827);
  static const _hintColor = Color(0xFF6B7280);
  static const _borderColor = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _fetchEmployeeInfo();
    _fetchLeaveBalance();
  }

  Future<void> _fetchEmployeeInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final hireDate = userDoc.data()?['hireDate'] as Timestamp?;
        setState(() {
          _hireDate = hireDate?.toDate();
          _employeeIdController.text = userDoc.data()?['employeeId'] ?? '';
        });
      }
    }
  }

  Future<void> _fetchLeaveBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      final balances = userDoc.data()?['leaveBalances'] as Map<String, dynamic>? ?? {};
      setState(() {
        _currentYearBalance = (balances['currentYear'] as num?)?.toDouble() ?? 0.0;
        _previousYearBalance = (balances['previousYear'] as num?)?.toDouble() ?? 0.0;
      });
    }
  }

  void _calculateLeaveDaysUsed() {
    if (_startDate == null || _endDate == null) {
      setState(() => _leaveDaysUsed = 0.0);
      return;
    }

    final difference = _endDate!.difference(_startDate!).inDays + 1;
    setState(() {
      _leaveDaysUsed = difference.toDouble();
      
      // Show warning if balance is insufficient for paid leave
      if (_selectedTypeConge == 'Congé de repos') {
        final totalBalance = _currentYearBalance + _previousYearBalance;
        if (difference > totalBalance) {
          _showSnackbar(
            'Attention: Votre solde est insuffisant pour cette période',
            Colors.orange,
          );
        }
      }
    });
  }

  Future<void> _showDateRangePicker(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : _endDate;
    final firstDate = isStartDate ? DateTime.now() : (_startDate ?? DateTime.now());

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: _cardColor,
            padding: const EdgeInsets.all(16),
            child: SfDateRangePicker(
              selectionMode: DateRangePickerSelectionMode.single,
              initialSelectedDate: initialDate,
              minDate: firstDate,
              maxDate: DateTime.now().add(const Duration(days: 365 * 2)),
              onSelectionChanged: (args) {
                if (args.value is DateTime) {
                  Navigator.pop(context);
                  setState(() {
                    if (isStartDate) {
                      _startDate = args.value as DateTime;
                      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
                        _endDate = null;
                      }
                    } else {
                      _endDate = args.value as DateTime;
                    }
                    _calculateLeaveDaysUsed();
                  });
                }
              },
              monthViewSettings: const DateRangePickerMonthViewSettings(
                firstDayOfWeek: 1,
                showTrailingAndLeadingDates: true,
              ),
              selectionColor: _primaryColor,
              todayHighlightColor: _secondaryColor,
              headerStyle: DateRangePickerHeaderStyle(
                textAlign: TextAlign.center,
                backgroundColor: Colors.transparent,
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              monthCellStyle: DateRangePickerMonthCellStyle(
                todayTextStyle: const TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.bold,
                ),
                textStyle: const TextStyle(color: _textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      _showSnackbar('Veuillez sélectionner les dates de début et de fin', _errorColor);
      return;
    }
    if (_selectedTypeConge == null) {
      _showSnackbar('Veuillez sélectionner un type de congé', _errorColor);
      return;
    }

    // Validate leave balance for paid leave only
    if (_selectedTypeConge == 'Congé de repos') {
      final totalBalance = _currentYearBalance + _previousYearBalance;
      if (_leaveDaysUsed > totalBalance) {
        _showSnackbar(
          'Solde insuffisant (${totalBalance.toStringAsFixed(1)} jours disponibles)',
          _errorColor,
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      await FirebaseFirestore.instance.collection('leave_requests').add({
        'userId': user.uid,
        'userName': userDoc.data()?['name'] ?? 'User',
        'employeeId': _employeeIdController.text.trim(),
        'hireDate': _hireDate != null ? Timestamp.fromDate(_hireDate!) : null,
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'daysRequested': _leaveDaysUsed,
        'reason': _reasonController.text.trim(),
        'typeConge': _selectedTypeConge,
        'status': 'pending',
        'requestedAt': Timestamp.now(),
        'leaveBalances': {
          'currentYear': _currentYearBalance,
          'previousYear': _previousYearBalance,
        },
      });

      _showSnackbar('Demande envoyée avec succès', _successColor);
      _resetForm();
    } catch (e) {
      _showSnackbar('Erreur: ${e.toString()}', _errorColor);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedTypeConge = null;
      _reasonController.clear();
      _leaveDaysUsed = 0.0;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sélectionner une date';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Demande de congé'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Employee Information Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person_outline, color: _primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Informations employé',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _textColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _employeeIdController,
                                decoration: InputDecoration(
                                  labelText: 'Identifiant employé',
                                  prefixIcon: Icon(Icons.badge, color: _primaryColor),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ce champ est obligatoire';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _hireDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null && picked != _hireDate) {
                                    setState(() {
                                      _hireDate = picked;
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Date de recrutement',
                                    prefixIcon: Icon(Icons.calendar_today, color: _primaryColor),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  child: Text(
                                    _formatDate(_hireDate),
                                    style: TextStyle(
                                      color: _hireDate == null ? _hintColor : _textColor,
                                    ),
                                  ),
                                ),
                              ),
                              if (_hireDate != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Ancienneté: ${_calculateSeniority()}',
                                  style: TextStyle(
                                    color: _hintColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Leave Type Selection
                      // In your "Leave Type Selection" Card widget, modify it like this:
Card(
  elevation: 2,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min, // Add this
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt, color: _primaryColor),
            const SizedBox(width: 8),
            Text(
              'Type de congé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container( // Add this Container
          height: 80,
          child: DropdownButtonFormField<String>(
            value: _selectedTypeConge,
            isExpanded: true,
            items: _leaveTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type['label'],
                child: ListTile(
                  leading: Icon(type['icon'], color: _primaryColor),
                  title: Text(type['label']),
                  subtitle: Text(
                    type['category'],
                    style: TextStyle(fontSize: 12, color: _hintColor),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedTypeConge = value),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              labelText: 'Sélectionner un type',
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ),
      ],
    ),
  ),
),

                      const SizedBox(height: 16),

                      // Leave Dates Selection
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_month, color: _primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Période de congé',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _textColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _showDateRangePicker(context, true),
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText: 'Date de début',
                                          prefixIcon: Icon(Icons.calendar_today, color: _primaryColor),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                        ),
                                        child: Text(
                                          _formatDate(_startDate),
                                          style: TextStyle(
                                            color: _startDate == null ? _hintColor : _textColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: InkWell(
                                      onTap: _startDate == null
                                          ? null
                                          : () => _showDateRangePicker(context, false),
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText: 'Date de fin',
                                          prefixIcon: Icon(Icons.calendar_today, color: _primaryColor),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                        ),
                                        child: Text(
                                          _formatDate(_endDate),
                                          style: TextStyle(
                                            color: _endDate == null ? _hintColor : _textColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_startDate != null && _endDate != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Durée totale:',
                                        style: TextStyle(
                                          color: _textColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${_endDate!.difference(_startDate!).inDays + 1} jours',
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Reason Field
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.note_alt_outlined, color: _primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Raison du congé',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _textColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _reasonController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: 'Décrivez la raison de votre congé',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty ? 'Ce champ est obligatoire' : null,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'SOUMETTRE LA DEMANDE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _calculateSeniority() {
    if (_hireDate == null) return '';
    
    final now = DateTime.now();
    final years = now.year - _hireDate!.year;
    final months = now.month - _hireDate!.month;
    final totalMonths = (now.year - _hireDate!.year) * 12 + (now.month - _hireDate!.month);
    
    if (totalMonths < 12) {
      return '$totalMonths mois';
    } else {
      return '$years an${years > 1 ? 's' : ''} ${months > 0 ? '$months mois' : ''}';
    }
  }
}