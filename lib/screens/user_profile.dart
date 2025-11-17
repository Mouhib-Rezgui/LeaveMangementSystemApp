import 'package:firebase/screens/EditLeaveRequestPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color primaryColor = Color(0xFF4361EE);
  static const Color secondaryColor = Color(0xFF3A0CA3);
  static const Color accentColor = Color(0xFF7209B7);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color cardColor = Colors.white;
  static const Color textDark = Color(0xFF212529);
  static const Color textLight = Color(0xFF495057);
  static const Color hintDark = Color(0xFF6C757D);

  late String userId;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    userId = _auth.currentUser!.uid;
  }

  List<Widget> get _pages => [
    _ProfileSection(auth: _auth, firestore: _firestore, userId: userId),
    _LeaveRequestsSection(firestore: _firestore, userId: userId),
    ChatSection(firestore: _firestore, userId: userId),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? "Mon profil"
              : _currentIndex == 1
                  ? "Demandes de congé"
                  : "Messages",
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: _currentIndex == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.edit, size: 22),
                  onPressed: () => Navigator.pushNamed(context, 'EditUserProfilePage'),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 22),
                  onPressed: () => _logout(context),
                ),
              ]
            : null,
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, 'DemandeCongePage'),
              backgroundColor: primaryColor,
              elevation: 4,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt_outlined),
          activeIcon: Icon(Icons.list_alt),
          label: 'Demandes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_outlined),
          activeIcon: Icon(Icons.chat),
          label: 'Chat',
        ),
      ],
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text(
          "Déconnexion",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Êtes-vous sûr de vouloir vous déconnecter ?"),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Annuler", style: TextStyle(color: hintDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Déconnexion",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout ?? false) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, "Login", (route) => false);
      }
    }
  }
}

class _ProfileSection extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final String userId;

  const _ProfileSection({
    required this.auth,
    required this.firestore,
    required this.userId,
  });

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  File? _profileImageFile;
  String? _localImagePath;
  final ImagePicker _picker = ImagePicker();
  double _currentYearBalance = 0;
  double _previousYearBalance = 0;
  double _totalBalance = 0;
  DateTime? _hireDate;

  @override
  void initState() {
    super.initState();
    _loadLocalImage();
    _loadUserData();
  }

  Future<void> _loadLocalImage() async {
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = '${directory.path}/profile_${widget.userId}.jpg';

    if (await File(imagePath).exists()) {
      setState(() {
        _localImagePath = imagePath;
        _profileImageFile = File(imagePath);
      });
    }
  }

  Future<void> _loadUserData() async {
    final userDoc = await widget.firestore.collection('users').doc(widget.userId).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      final hireDate = data['hireDate'] as Timestamp?;
      
      setState(() {
        _hireDate = hireDate?.toDate();
      });
      
      // Calculate balances based on hire date
      _calculateLeaveBalances();
    }
  }

  void _calculateLeaveBalances() {
    if (_hireDate == null) return;

    final now = DateTime.now();
    final hireYear = _hireDate!.year;
    final hireMonth = _hireDate!.month;
    final currentYear = now.year;
    final currentMonth = now.month;
    
    // Calculate months worked
    final monthsWorked = (currentYear - hireYear) * 12 + (currentMonth - hireMonth);
    
    // Reset balances
    _currentYearBalance = 0;
    _previousYearBalance = 0;

    // For employees with less than 1 year of service
    if (monthsWorked < 12) {
      _currentYearBalance = 0;
      _previousYearBalance = 0;
    } 
    // For employees with exactly 1 year of service
    else if (monthsWorked >= 12 && monthsWorked < 24) {
      _currentYearBalance = 30;
      _previousYearBalance = 0;
    }
    // For employees with more than 1 year of service
    else {
      _currentYearBalance = 30;
      _previousYearBalance = 30;
    }

    // Update the total balance
    setState(() {
      _totalBalance = _currentYearBalance + _previousYearBalance;
    });
  }

  Future<void> _pickAndUploadImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Mettre à jour la photo de profil",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _UserProfilePageState.textDark,
                  ),
                ),
              ),
              Divider(height: 1, color: Colors.grey[200]),
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: _UserProfilePageState.primaryColor,
                ),
                title: const Text('Prendre une photo'),
                onTap: () async {
                  Navigator.pop(modalContext);
                  final pickedFile = await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 600,
                  );
                  if (pickedFile != null) {
                    await _saveImageLocally(File(pickedFile.path));
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: _UserProfilePageState.primaryColor,
                ),
                title: const Text('Choisissez dans la galerie'),
                onTap: () async {
                  Navigator.pop(modalContext);
                  final pickedFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 600,
                  );
                  if (pickedFile != null) {
                    await _saveImageLocally(File(pickedFile.path));
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveImageLocally(File imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_${widget.userId}.jpg';

      await imageFile.copy(imagePath);

      setState(() {
        _profileImageFile = File(imagePath);
        _localImagePath = imagePath;
      });

      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(
            content: const Text("Photo de profil mise à jour avec succès"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: _UserProfilePageState.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(
            content: Text("Error uploading image: ${e.toString()}"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.firestore.collection('users').doc(widget.userId).snapshots(),
      builder: (BuildContext streamContext, AsyncSnapshot<DocumentSnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Text(
              'No user data found',
              style: TextStyle(color: _UserProfilePageState.textDark),
            ),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final balances = userData['leaveBalances'] as Map<String, dynamic>? ?? {
          'currentYear': 0,
          'previousYear': 0
        };

        // Use Firestore balances if they exist, otherwise use calculated values
        final displayCurrentYear = (balances['currentYear'] ?? _currentYearBalance).toDouble();
        final displayPreviousYear = (balances['previousYear'] ?? _previousYearBalance).toDouble();
        final displayTotal = displayCurrentYear + displayPreviousYear;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _UserProfilePageState.primaryColor.withOpacity(0.2),
                        width: 4,
                      ),
                    ),
                    child: _profileImageFile != null
                        ? CircleAvatar(
                            radius: 60,
                            backgroundImage: FileImage(_profileImageFile!),
                          )
                        : CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[200],
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                          ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: _UserProfilePageState.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _pickAndUploadImage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                userData['name'] ?? '',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: _UserProfilePageState.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userData['email'] ?? '',
                style: TextStyle(fontSize: 16, color: _UserProfilePageState.hintDark),
              ),
              const SizedBox(height: 32),
              _buildInfoCard(
                title: "Role",
                value: userData['role'] ?? 'Employee',
                icon: Icons.work_outline,
              ),
              const SizedBox(height: 16),
              _buildLeaveBalanceCard(
                currentYear: displayCurrentYear,
                previousYear: displayPreviousYear,
                total: displayTotal,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _UserProfilePageState.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: _UserProfilePageState.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: _UserProfilePageState.hintDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _UserProfilePageState.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveBalanceCard({
    required double currentYear,
    required double previousYear,
    required double total,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _UserProfilePageState.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: _UserProfilePageState.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "Solde de congé",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _UserProfilePageState.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBalanceInfoTile(
              'Année courante (${DateTime.now().year})',
              currentYear,
              Icons.calendar_today,
            ),
            const Divider(height: 24),
            _buildBalanceInfoTile(
              'Année précédente (${DateTime.now().year - 1})',
              previousYear,
              Icons.history,
            ),
            const Divider(height: 24),
            _buildBalanceInfoTile(
              'Total disponible',
              total,
              Icons.account_balance,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceInfoTile(
    String title,
    double value,
    IconData icon, {
    bool isTotal = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: _UserProfilePageState.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: _UserProfilePageState.textDark,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isTotal
                  ? _UserProfilePageState.primaryColor.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isTotal
                  ? Border.all(color: _UserProfilePageState.primaryColor)
                  : null,
            ),
            child: Text(
              '${value.toStringAsFixed(1)} jours',
              style: TextStyle(
                color: _UserProfilePageState.textDark,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _LeaveRequestsSection extends StatefulWidget {
  final FirebaseFirestore firestore;
  final String userId;

  const _LeaveRequestsSection({required this.firestore, required this.userId});

  @override
  State<_LeaveRequestsSection> createState() => _LeaveRequestsSectionState();
}

class _LeaveRequestsSectionState extends State<_LeaveRequestsSection> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final leaveRequestsStream = widget.firestore
        .collection('leave_requests')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('requestedAt', descending: true)
        .snapshots();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher des demandes...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _UserProfilePageState.primaryColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: leaveRequestsStream,
            builder: (BuildContext streamContext, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: _UserProfilePageState.primaryColor,
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.list_alt_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Aucune demande de congé trouvée",
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              final filteredDocs = docs.where((doc) {
                final req = doc.data()! as Map<String, dynamic>;
                final type = req['typeConge']?.toString().toLowerCase() ?? '';
                final reason = req['reason']?.toString().toLowerCase() ?? '';
                final status = req['status']?.toString().toLowerCase() ?? '';

                return type.contains(_searchQuery) ||
                    reason.contains(_searchQuery) ||
                    status.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "Aucune demande correspondante",
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: filteredDocs.length,
                itemBuilder: (BuildContext listContext, int index) {
                  final req = filteredDocs[index].data()! as Map<String, dynamic>;
                  final startDate = (req['startDate'] as Timestamp).toDate();
                  final endDate = (req['endDate'] as Timestamp).toDate();
                  final status = (req['status'] ?? 'pending').toString().toLowerCase();

                  Color statusColor;
                  String statusText;
                  IconData statusIcon;

                  switch (status) {
                    case 'approved':
                      statusColor = Colors.green;
                      statusText = "Approuvé";
                      statusIcon = Icons.check_circle_outline;
                      break;
                    case 'rejected':
                      statusColor = Colors.red;
                      statusText = "Rejeté";
                      statusIcon = Icons.cancel_outlined;
                      break;
                    default:
                      statusColor = Colors.orange;
                      statusText = "En attente";
                      statusIcon = Icons.pending_outlined;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: status == 'en attente' || status == 'pending'
                          ? () {
                              Navigator.push(
                                listContext,
                                MaterialPageRoute(
                                  builder: (BuildContext _) => EditLeaveRequestPage(
                                    requestId: filteredDocs[index].id,
                                    initialData: req,
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  req['typeConge'] ?? 'Type inconnu',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: _UserProfilePageState.textDark,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        statusIcon,
                                        size: 18,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.date_range_outlined,
                                  size: 20,
                                  color: _UserProfilePageState.hintDark,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _UserProfilePageState.textLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 20,
                                  color: _UserProfilePageState.hintDark,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${req['daysRequested']?.toString() ?? '0'} jours demandés",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _UserProfilePageState.textLight,
                                  ),
                                ),
                              ],
                            ),
                            if ((req['reason'] ?? '').toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                "Raison:",
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: _UserProfilePageState.textDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                req['reason'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _UserProfilePageState.textLight,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ChatSection extends StatefulWidget {
  final FirebaseFirestore firestore;
  final String userId;

  const ChatSection({required this.firestore, required this.userId});

  @override
  State<ChatSection> createState() => _ChatSectionState();
}

class _ChatSectionState extends State<ChatSection> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _recipientId = '';
  String _recipientName = '';

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _recipientId.isEmpty) return;

    final message = {
      'senderId': widget.userId,
      'recipientId': _recipientId,
      'message': _messageController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    try {
      await widget.firestore.collection('messages').add(message);
      _messageController.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildMessageBubble(DocumentSnapshot message) {
    final data = message.data()! as Map<String, dynamic>;
    final isMe = data['senderId'] == widget.userId;
    final messageText = data['message'] ?? '';
    final timestamp =
        data['timestamp'] != null
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color:
                  isMe ? _UserProfilePageState.primaryColor : Colors.grey[200],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft:
                    isMe ? const Radius.circular(16) : const Radius.circular(4),
                bottomRight:
                    isMe ? const Radius.circular(4) : const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messageText,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(timestamp),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectRecipient() async {
    final result = await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Sélectionner le destinataire',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _UserProfilePageState.textDark,
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.grey[200]),
                Flexible(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: widget.firestore.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final users =
                          snapshot.data!.docs.where((doc) {
                            return doc.id != widget.userId;
                          }).toList();

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user =
                              users[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _UserProfilePageState
                                  .primaryColor
                                  .withOpacity(0.1),
                              child: Icon(
                                Icons.person_outline,
                                color: _UserProfilePageState.primaryColor,
                              ),
                            ),
                            title: Text(
                              user['name'] ?? 'Unknown User',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            onTap: () {
                              Navigator.pop(context, {
                                'id': users[index].id,
                                'name': user['name'] ?? 'Unknown User',
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _recipientId = result['id'];
        _recipientName = result['name'];
      });
    }
  }

  Stream<QuerySnapshot> _getMessagesStream() {
    if (_recipientId.isEmpty) {
      return const Stream.empty();
    }

    return widget.firestore
        .collection('messages')
        .where(
          Filter.or(
            Filter.and(
              Filter('senderId', isEqualTo: widget.userId),
              Filter('recipientId', isEqualTo: _recipientId),
            ),
            Filter.and(
              Filter('senderId', isEqualTo: _recipientId),
              Filter('recipientId', isEqualTo: widget.userId),
            ),
          ),
        )
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_recipientId.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune conversation sélectionnée',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _selectRecipient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _UserProfilePageState.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Sélectionner le destinataire',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          setState(() {
                            _recipientId = '';
                            _recipientName = '';
                          });
                        },
                      ),
                      title: Text(
                        _recipientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_add),
                        onPressed: _selectRecipient,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: _UserProfilePageState.backgroundLight,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _getMessagesStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: _UserProfilePageState.primaryColor,
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Aucun message pour le moment",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final messages = snapshot.data!.docs;

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(
                              _scrollController.position.maxScrollExtent,
                            );
                          }
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(messages[index]);
                          },
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Tapez un message...',
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _UserProfilePageState.primaryColor,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}