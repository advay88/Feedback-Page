import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FeedbackPage extends StatefulWidget {
  @override
  _FeedbackPageState createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _feedbackController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _feedbackId; // Used to track if the feedback is being edited

  Future<void> _submitFeedback() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final feedbackText = _feedbackController.text.trim();

      if (_feedbackId == null) {
        // Adding new feedback
        await FirebaseFirestore.instance.collection('feedback').add({
          'userId': user!.uid,
          'feedback': feedbackText,
          'timestamp': Timestamp.now(),
        });
      } else {
        // Updating existing feedback
        await FirebaseFirestore.instance
            .collection('feedback')
            .doc(_feedbackId)
            .update({
          'feedback': feedbackText,
          'timestamp': Timestamp.now(),
        });
      }

      // Clear the form after submission
      _feedbackController.clear();
      _feedbackId = null;
    } on FirebaseException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFeedbackForEditing(DocumentSnapshot doc) async {
    setState(() {
      _feedbackController.text = doc['feedback'];
      _feedbackId = doc.id;
    });
  }

  Future<void> _deleteFeedback(String id) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('feedback').doc(id).delete();
    } on FirebaseException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Feedback'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Your Feedback',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
              SizedBox(height: 16),
            ],
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submitFeedback,
                    child: Text(_feedbackId == null ? 'Submit' : 'Update'),
                  ),
            SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('feedback')
                    .where('userId', isEqualTo: user!.uid)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final feedbackDocs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: feedbackDocs.length,
                    itemBuilder: (context, index) {
                      final feedbackDoc = feedbackDocs[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(feedbackDoc['feedback']),
                          subtitle: Text(
                            feedbackDoc['timestamp']
                                .toDate()
                                .toString(), // Display timestamp
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () =>
                                    _loadFeedbackForEditing(feedbackDoc),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () =>
                                    _deleteFeedback(feedbackDoc.id),
                              ),
                            ],
                          ),
                        ),
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
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}
