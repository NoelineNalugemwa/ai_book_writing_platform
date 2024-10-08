import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'book_reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _selectedGenre = 'All';
  String _selectedAudience = 'All';
  String _selectedLanguage = 'All';
  final List<String> _selectedTags = [];

  List<String> _genres = ['All'];
  final List<String> _audiences = [
    'All',
    'General',
    'Children',
    'Young Adult',
    'Adult'
  ];
  final List<String> _languages = [
    'All',
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese',
    'Other'
  ];
  List<String> _allTags = [];

  @override
  void initState() {
    super.initState();
    _loadGenres();
    _loadTags();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadGenres() async {
    try {
      var genresSnapshot = await _firestore.collection('genres').get();
      if (mounted) {
        setState(() {
          _genres = [
            'All',
            ...genresSnapshot.docs.map((doc) => doc['name'] as String)
          ];
        });
      }
    } catch (e) {
      print('Error loading genres: $e');
    }
  }

  void _loadTags() async {
    try {
      var tagsSnapshot = await _firestore.collection('tags').get();
      if (mounted) {
        setState(() {
          _allTags =
              tagsSnapshot.docs.map((doc) => doc['name'] as String).toList();
        });
      }
    } catch (e) {
      print('Error loading tags: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Library'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterOptions(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('books')
                  .where('isPublished', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No public books available.'));
                }

                var books = snapshot.data!.docs;
                books = books.where((book) {
                  var data = book.data() as Map<String, dynamic>;
                  bool matchesSearch = data['title']
                      .toString()
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                  bool matchesGenre = _selectedGenre == 'All' ||
                      data['genre'] == _selectedGenre;
                  bool matchesAudience = _selectedAudience == 'All' ||
                      data['targetAudience'] == _selectedAudience;
                  bool matchesLanguage = _selectedLanguage == 'All' ||
                      data['language'] == _selectedLanguage;
                  bool matchesTags = _selectedTags.isEmpty ||
                      (data['tags'] as List<dynamic>)
                          .any((tag) => _selectedTags.contains(tag));
                  return matchesSearch &&
                      matchesGenre &&
                      matchesAudience &&
                      matchesLanguage &&
                      matchesTags;
                }).toList();

                if (books.isEmpty) {
                  return const Center(
                      child: Text('No books match your search criteria.'));
                }

                return _buildBookGrid(books);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search books',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildFilterOptions() {
    return ExpansionTile(
      title: const Text('Filters'),
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Genre'),
          value: _selectedGenre,
          items: _genres
              .map(
                  (genre) => DropdownMenuItem(value: genre, child: Text(genre)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedGenre = value!;
            });
          },
        ),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Target Audience'),
          value: _selectedAudience,
          items: _audiences
              .map((audience) =>
                  DropdownMenuItem(value: audience, child: Text(audience)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedAudience = value!;
            });
          },
        ),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Language'),
          value: _selectedLanguage,
          items: _languages
              .map((language) =>
                  DropdownMenuItem(value: language, child: Text(language)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedLanguage = value!;
            });
          },
        ),
        Wrap(
          spacing: 8,
          children: _allTags
              .map((tag) => FilterChip(
                    label: Text(tag),
                    selected: _selectedTags.contains(tag),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildBookGrid(List<QueryDocumentSnapshot> books) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // Increased to 4 books per row
        childAspectRatio: 0.7,
        crossAxisSpacing: 4, // Reduced spacing
        mainAxisSpacing: 4, // Reduced spacing
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        var book = books[index].data() as Map<String, dynamic>;
        return _buildBookCard(book, books[index].id);
      },
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book, String bookId) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookReaderScreen(bookId: bookId),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: book['coverImage'] != null
                  ? CachedNetworkImage(
                      imageUrl: book['coverImage'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child:
                            Icon(Icons.book, size: 40, color: Colors.grey[600]),
                      ),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child:
                          Icon(Icons.book, size: 40, color: Colors.grey[600]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(2.0), // Reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book['title'] ?? 'Untitled',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10), // Smaller font
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    book['authorName'] ?? 'Unknown author',
                    style: TextStyle(
                        fontSize: 8, color: Colors.grey[600]), // Smaller font
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
