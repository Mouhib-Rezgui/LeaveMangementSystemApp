import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _currentIndex = 0;

  // Navigation pages
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _LeaveRequestsPage(firestore: _firestore),
      _StatsPage(firestore: _firestore),
      ChatSection(firestore: _firestore, userId: _auth.currentUser!.uid),
      _ProfilePage(auth: _auth, firestore: _firestore),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? "Demandes de Congés"
              : _currentIndex == 1
                  ? "Tableau de Bord"
                  : _currentIndex == 2
                      ? "Messages"
                      : "Profil Admin",
        ),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        centerTitle: true,
        actions: _currentIndex == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.filter_alt),
                  onPressed: () => _showFilterDialog(context),
                ),
              ]
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade800.withOpacity(0.1), Colors.white],
          ),
        ),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt_outlined),
          activeIcon: Icon(Icons.list_alt),
          label: 'Demandes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          activeIcon: Icon(Icons.analytics),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_outlined),
          activeIcon: Icon(Icons.chat),
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
      selectedItemColor: Colors.blue.shade800,
      unselectedItemColor: Colors.grey,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
    );
  }

  Future<void> _showFilterDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Filtrer les demandes"),
        content: const Text("Fonctionnalité de filtre à venir..."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}

class _LeaveRequestsPage extends StatefulWidget {
  final FirebaseFirestore firestore;

  const _LeaveRequestsPage({required this.firestore});

  @override
  State<_LeaveRequestsPage> createState() => _LeaveRequestsPageState();
}

class _LeaveRequestsPageState extends State<_LeaveRequestsPage> {
  String _filterStatus = 'pending';
  String _searchQuery = '';

  Future<void> _handleApproval(
    BuildContext context,
    String docId,
    Map<String, dynamic> requestData,
) async {
    try {
        final userDoc = await widget.firestore
            .collection('users')
            .doc(requestData['userId'])
            .get();

        if (!userDoc.exists) {
            if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Utilisateur non trouvé"),
                        backgroundColor: Colors.red,
                    ),
                );
            }
            return;
        }

        final userData = userDoc.data() as Map<String, dynamic>;
        final balances = userData['leaveBalances'] as Map<String, dynamic>? ?? {};
        
        final currentYear = (balances['currentYear'] as num?)?.toDouble() ?? 0.0;
        final previousYear = (balances['previousYear'] as num?)?.toDouble() ?? 0.0;

        final startDate = (requestData['startDate'] as Timestamp).toDate();
        final endDate = (requestData['endDate'] as Timestamp).toDate();
        final daysRequested = _calculateActualDays(startDate, endDate); // Changed this line

        if ((currentYear + previousYear) < daysRequested) {
            if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Solde insuffisant pour approbation"),
                        backgroundColor: Colors.red,
                    ),
                );
            }
            return;
        }

        double newPreviousYear = previousYear;
        double newCurrentYear = currentYear;
        double daysFromPrevious = 0;

        if (previousYear > 0) {
            daysFromPrevious = daysRequested <= previousYear
                ? daysRequested
                : previousYear;
            newPreviousYear = previousYear - daysFromPrevious;
        }

        newCurrentYear = currentYear - (daysRequested - daysFromPrevious);

        await widget.firestore.runTransaction((transaction) async {
            transaction.update(
                widget.firestore.collection('leave_requests').doc(docId),
                {
                    'status': 'approved',
                    'processedAt': FieldValue.serverTimestamp(),
                    'daysUsed': daysRequested,
                    'leaveBalances': {
                        'currentYearAtApproval': currentYear,
                        'previousYearAtApproval': previousYear,
                    },
                },
            );

            transaction.update(
                widget.firestore.collection('users').doc(requestData['userId']),
                {
                    'leaveBalances': {
                        'currentYear': newCurrentYear,
                        'previousYear': newPreviousYear,
                    },
                },
            );
        });

        if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Demande approuvée avec succès"),
                    backgroundColor: Colors.green,
                ),
            );
        }
    } catch (e) {
        if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text("Erreur lors de l'approbation: ${e.toString()}"),
                    backgroundColor: Colors.red,
                ),
            );
        }
    }
}

// Replace the special deduction calculation with this:
double _calculateActualDays(DateTime startDate, DateTime endDate) {
    return endDate.difference(startDate).inDays + 1; // Actual calendar days
}

  Future<void> _handleRejection(BuildContext context, String docId) async {
    final confirmReject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer le rejet"),
        content: const Text("Voulez-vous vraiment rejeter cette demande ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Rejeter"),
          ),
        ],
      ),
    );

    if (confirmReject ?? false) {
      try {
        await widget.firestore.collection('leave_requests').doc(docId).update({
          'status': 'rejected',
          'processedAt': FieldValue.serverTimestamp(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Demande rejetée"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur lors du rejet: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
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
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                onSelected: (value) => setState(() => _filterStatus = value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'pending',
                    child: Text('En attente'),
                  ),
                  const PopupMenuItem(
                    value: 'approved',
                    child: Text('Approuvées'),
                  ),
                  const PopupMenuItem(
                    value: 'rejected',
                    child: Text('Rejetées'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.firestore
                .collection('leave_requests')
                .where('status', isEqualTo: _filterStatus)
                .orderBy('requestedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur de chargement: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "Aucune demande trouvée",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final requests = snapshot.data!.docs.where((doc) {
                final req = doc.data() as Map<String, dynamic>;
                final userName = req['userName']?.toString().toLowerCase() ?? '';
                final type = req['typeConge']?.toString().toLowerCase() ?? '';
                return userName.contains(_searchQuery.toLowerCase()) ||
                    type.contains(_searchQuery.toLowerCase());
              }).toList();

              if (requests.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "Aucun résultat trouvé",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index].data() as Map<String, dynamic>;
                  final docId = requests[index].id;
                  
                  try {
                    final startDate = (req['startDate'] as Timestamp).toDate();
                    final endDate = (req['endDate'] as Timestamp).toDate();
                    final daysRequested = endDate.difference(startDate).inDays + 1;
                    
                    final balances = req['leaveBalances'] as Map<String, dynamic>? ?? {};
                    final currentYear = (balances['currentYear'] as num?)?.toInt() ?? 0;
                    final previousYear = (balances['previousYear'] as num?)?.toInt() ?? 0;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(req['status']),
                          child: Icon(
                            _getStatusIcon(req['status']),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          req['userName'] ?? 'Employé inconnu',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}",
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),
                                _buildInfoRow("Type", req['typeConge'] ?? 'Non spécifié'),
                                _buildInfoRow("Durée", "$daysRequested jours"),
                                if (req['reason'] != null)
                                  _buildInfoRow("Raison", req['reason']),
                                const SizedBox(height: 8),
                                _buildBalanceInfo(req['userId'], daysRequested),
                                if (_filterStatus == 'pending') ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => _handleRejection(context, docId),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                        ),
                                        child: const Text("Rejeter"),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => _handleApproval(context, docId, req),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        child: const Text(
                                          "Approuver",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.error_outline, color: Colors.orange),
                        title: const Text("Demande incomplète", style: TextStyle(color: Colors.red)),
                        subtitle: Text(
                          "Certaines données sont manquantes ou invalides", 
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deleteInvalidRequest(docId);
                          },
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _deleteInvalidRequest(String docId) async {
    try {
      await widget.firestore.collection('leave_requests').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Demande invalide supprimée"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la suppression: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo(String userId, int daysRequested) {
    return FutureBuilder<DocumentSnapshot>(
      future: widget.firestore.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Text('Erreur de chargement des soldes');
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final balances = userData['leaveBalances'] as Map<String, dynamic>? ?? {};
        final currentYear = (balances['currentYear'] as num?)?.toDouble() ?? 0.0;
        final previousYear = (balances['previousYear'] as num?)?.toDouble() ?? 0.0;

        final newCombinedBalance = (currentYear + previousYear) - daysRequested;
        final hasSufficientBalance = newCombinedBalance >= 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildBalanceRow("Solde actuel (Année courante)", currentYear),
              _buildBalanceRow("Solde année précédente", previousYear),
              if (previousYear > 0)
                _buildBalanceRow("Total disponible", (currentYear + previousYear)),
              const Divider(height: 16),
              _buildBalanceRow(
                "Nouveau solde après approbation",
                newCombinedBalance,
                isTotal: true,
                isPositive: hasSufficientBalance,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceRow(
    String label,
    double value, {
    bool isTotal = false,
    bool isPositive = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            "${value.toStringAsFixed(1)} jours",
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal
                  ? isPositive
                      ? Colors.green
                      : Colors.red
                  : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check;
      case 'rejected':
        return Icons.close;
      default:
        return Icons.pending;
    }
  }
}
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ChartData {
  final String type;
  final int value;

  _ChartData(this.type, this.value);
}

class _StatsPage extends StatelessWidget {
  final FirebaseFirestore firestore;

  const _StatsPage({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              minWidth: constraints.maxWidth,
            ),
            child: Column(
              children: [
                _buildResponsiveQuickStatsSection(constraints),
                const SizedBox(height: 24),
                _buildResponsiveLeaveTypeChart(constraints),
                const SizedBox(height: 24),
                _buildResponsiveMonthlyStatsChart(constraints),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveQuickStatsSection(BoxConstraints constraints) {
    return FutureBuilder<List<AggregateQuerySnapshot>>(
      future: Future.wait([
        firestore.collection('leave_requests').count().get(),
        firestore
            .collection('leave_requests')
            .where('status', isEqualTo: 'approved')
            .count()
            .get(),
        firestore
            .collection('leave_requests')
            .where('status', isEqualTo: 'rejected')
            .count()
            .get(),
        firestore
            .collection('leave_requests')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final total = snapshot.data?[0].count ?? 0;
        final approved = snapshot.data?[1].count ?? 0;
        final rejected = snapshot.data?[2].count ?? 0;
        final pending = snapshot.data?[3].count ?? 0;
        final approvalRate = total > 0 ? (approved / total * 100) : 0;

        return constraints.maxWidth > 600
            ? Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Demandes',
                          value: total.toString(),
                          icon: Icons.list_alt,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'Taux Approbation',
                          value: '${approvalRate.toStringAsFixed(1)}%',
                          icon: Icons.bar_chart,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Approuvées',
                          value: approved.toString(),
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'Rejetées',
                          value: rejected.toString(),
                          icon: Icons.cancel,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'En Attente',
                          value: pending.toString(),
                          icon: Icons.pending,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                children: [
                  _StatCard(
                    title: 'Total Demandes',
                    value: total.toString(),
                    icon: Icons.list_alt,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _StatCard(
                    title: 'Taux Approbation',
                    value: '${approvalRate.toStringAsFixed(1)}%',
                    icon: Icons.bar_chart,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _StatCard(
                    title: 'Approuvées',
                    value: approved.toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _StatCard(
                    title: 'Rejetées',
                    value: rejected.toString(),
                    icon: Icons.cancel,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  _StatCard(
                    title: 'En Attente',
                    value: pending.toString(),
                    icon: Icons.pending,
                    color: Colors.orange,
                  ),
                ],
              );
      },
    );
  }

  Widget _buildResponsiveLeaveTypeChart(BoxConstraints constraints) {
    return FutureBuilder<QuerySnapshot>(
      future: firestore.collection('leave_requests').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('Error loading data'));
        }

        final requests = snapshot.data!.docs;
        final typeCounts = <String, int>{};

        for (var req in requests) {
          final type =
              (req.data() as Map<String, dynamic>)['typeConge'] ?? 'Autre';
          typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        }

        final chartData =
            typeCounts.entries.map((e) => _ChartData(e.key, e.value)).toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Répartition par Type de Congé',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  width: constraints.maxWidth * 0.9,
                  child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(),
                    series: <CartesianSeries<_ChartData, String>>[
                      BarSeries<_ChartData, String>(
                        dataSource: chartData,
                        xValueMapper: (_ChartData data, _) => data.type,
                        yValueMapper: (_ChartData data, _) => data.value,
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                        ),
                        color: Colors.blue.shade800,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveMonthlyStatsChart(BoxConstraints constraints) {
    return FutureBuilder<QuerySnapshot>(
      future:
          firestore.collection('leave_requests').orderBy('requestedAt').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('Error loading data'));
        }

        final requests = snapshot.data!.docs;
        final monthlyStats = <String, int>{};
        final now = DateTime.now();
        final months = <String>[];

        // Initialize last 6 months
        for (var i = 5; i >= 0; i--) {
          final date = DateTime(now.year, now.month - i, 1);
          final monthKey = DateFormat('MMM yyyy').format(date);
          months.add(monthKey);
          monthlyStats[monthKey] = 0;
        }

        for (var req in requests) {
          final timestamp =
              (req.data() as Map<String, dynamic>)['requestedAt'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            final monthKey = DateFormat('MMM yyyy').format(date);
            if (monthlyStats.containsKey(monthKey)) {
              monthlyStats[monthKey] = monthlyStats[monthKey]! + 1;
            }
          }
        }

        final chartData =
            months
                .map((month) => _ChartData(month, monthlyStats[month] ?? 0))
                .toList();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Demandes par Mois (6 derniers mois)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  width: constraints.maxWidth * 0.9,
                  child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(),
                    series: <CartesianSeries<_ChartData, String>>[
                      BarSeries<_ChartData, String>(
                        dataSource: chartData,
                        xValueMapper: (_ChartData data, _) => data.type,
                        yValueMapper: (_ChartData data, _) => data.value,
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                        ),
                        color: Colors.blue.shade800,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfilePage extends StatelessWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  const _ProfilePage({required this.auth, required this.firestore});

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer la déconnexion"),
        content: const Text("Voulez-vous vraiment vous déconnecter ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
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
      await auth.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, "Login", (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: firestore.collection('users').doc(auth.currentUser!.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('User not found'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue.shade800.withOpacity(0.2),
                        width: 4,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.blue.shade800,
                      child: const Icon(
                        Icons.admin_panel_settings,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade800,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                data['name'] ?? 'No name',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data['email'] ?? 'No email',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildProfileInfoRow(
                        Icons.work,
                        "Rôle",
                        data['role'] ?? 'Administrateur',
                      ),
                      const Divider(),
                      _buildProfileInfoRow(
                        Icons.date_range,
                        "Membre depuis",
                        createdAt != null
                            ? DateFormat('dd MMMM yyyy').format(createdAt)
                            : 'Inconnu',
                      ),
                      const Divider(),
                      _buildProfileInfoRow(
                        Icons.security,
                        "Permissions",
                        "Accès complet au système",
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Déconnexion'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _logout(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade800),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                  isMe ? Colors.blue.shade800 : Colors.grey[200],
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
                      color: Colors.blue.shade800,
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
                              backgroundColor: Colors.blue.shade800.withOpacity(0.1),
                              child: Icon(
                                Icons.person_outline,
                                color: Colors.blue.shade800,
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
                      backgroundColor: Colors.blue.shade800,
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
                    color: Colors.grey[50],
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _getMessagesStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Colors.blue.shade800,
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
                          color: Colors.blue.shade800,
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