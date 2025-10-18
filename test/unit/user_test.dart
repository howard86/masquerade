import 'package:flutter_test/flutter_test.dart';
import 'package:masquerade/features/user/domain/entities/user.dart';

/// Unit tests for User entity
/// This file should trigger testing-specific Flutter rules
void main() {
  group('User Entity', () {
    late User testUser;

    setUp(() {
      testUser = User(
        id: '123',
        name: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 2),
      );
    });

    group('Constructor', () {
      test('should create a user with valid data', () {
        // Arrange
        const id = '123';
        const name = 'John Doe';
        const email = 'john@example.com';
        final createdAt = DateTime(2023, 1, 1);
        final updatedAt = DateTime(2023, 1, 2);

        // Act
        final user = User(
          id: id,
          name: name,
          email: email,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        // Assert
        expect(user.id, equals(id));
        expect(user.name, equals(name));
        expect(user.email, equals(email));
        expect(user.createdAt, equals(createdAt));
        expect(user.updatedAt, equals(updatedAt));
        expect(user.isActive, isTrue);
        expect(user.role, equals(UserRole.user));
      });

      test('should create a user with all optional parameters', () {
        // Arrange
        const id = '123';
        const name = 'John Doe';
        const email = 'john@example.com';
        const avatarUrl = 'https://example.com/avatar.jpg';
        final createdAt = DateTime(2023, 1, 1);
        final updatedAt = DateTime(2023, 1, 2);
        const isActive = false;
        const role = UserRole.admin;

        // Act
        final user = User(
          id: id,
          name: name,
          email: email,
          avatarUrl: avatarUrl,
          createdAt: createdAt,
          updatedAt: updatedAt,
          isActive: isActive,
          role: role,
        );

        // Assert
        expect(user.id, equals(id));
        expect(user.name, equals(name));
        expect(user.email, equals(email));
        expect(user.avatarUrl, equals(avatarUrl));
        expect(user.createdAt, equals(createdAt));
        expect(user.updatedAt, equals(updatedAt));
        expect(user.isActive, equals(isActive));
        expect(user.role, equals(role));
      });
    });

    group('copyWith', () {
      test('should create a copy with updated fields', () {
        // Act
        final updatedUser = testUser.copyWith(
          name: 'Jane Doe',
          email: 'jane@example.com',
        );

        // Assert
        expect(updatedUser.id, equals(testUser.id));
        expect(updatedUser.name, equals('Jane Doe'));
        expect(updatedUser.email, equals('jane@example.com'));
        expect(updatedUser.createdAt, equals(testUser.createdAt));
        expect(updatedUser.updatedAt, equals(testUser.updatedAt));
      });

      test(
        'should create a copy with no changes when no parameters provided',
        () {
          // Act
          final copiedUser = testUser.copyWith();

          // Assert
          expect(copiedUser, equals(testUser));
        },
      );
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        // Act
        final json = testUser.toJson();

        // Assert
        expect(json['id'], equals(testUser.id));
        expect(json['name'], equals(testUser.name));
        expect(json['email'], equals(testUser.email));
        expect(json['avatar_url'], equals(testUser.avatarUrl));
        expect(
          json['created_at'],
          equals(testUser.createdAt.toIso8601String()),
        );
        expect(
          json['updated_at'],
          equals(testUser.updatedAt.toIso8601String()),
        );
        expect(json['is_active'], equals(testUser.isActive));
        expect(json['role'], equals(testUser.role.value));
      });

      test('should deserialize from JSON correctly', () {
        // Arrange
        final json = {
          'id': '123',
          'name': 'John Doe',
          'email': 'john@example.com',
          'avatar_url': 'https://example.com/avatar.jpg',
          'created_at': '2023-01-01T00:00:00.000Z',
          'updated_at': '2023-01-02T00:00:00.000Z',
          'is_active': true,
          'role': 'admin',
        };

        // Act
        final user = User.fromJson(json);

        // Assert
        expect(user.id, equals('123'));
        expect(user.name, equals('John Doe'));
        expect(user.email, equals('john@example.com'));
        expect(user.avatarUrl, equals('https://example.com/avatar.jpg'));
        expect(
          user.createdAt,
          equals(DateTime.parse('2023-01-01T00:00:00.000Z')),
        );
        expect(
          user.updatedAt,
          equals(DateTime.parse('2023-01-02T00:00:00.000Z')),
        );
        expect(user.isActive, isTrue);
        expect(user.role, equals(UserRole.admin));
      });
    });

    group('Equality', () {
      test('should be equal when all properties are the same', () {
        // Arrange
        final user1 = User(
          id: '123',
          name: 'John Doe',
          email: 'john@example.com',
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 2),
        );

        final user2 = User(
          id: '123',
          name: 'John Doe',
          email: 'john@example.com',
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Assert
        expect(user1, equals(user2));
        expect(user1.hashCode, equals(user2.hashCode));
      });

      test('should not be equal when properties differ', () {
        // Arrange
        final user1 = User(
          id: '123',
          name: 'John Doe',
          email: 'john@example.com',
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 2),
        );

        final user2 = User(
          id: '456',
          name: 'Jane Doe',
          email: 'jane@example.com',
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 2),
        );

        // Assert
        expect(user1, isNot(equals(user2)));
      });
    });

    group('toString', () {
      test('should return string representation', () {
        // Act
        final string = testUser.toString();

        // Assert
        expect(string, contains('User'));
        expect(string, contains(testUser.id));
        expect(string, contains(testUser.name));
        expect(string, contains(testUser.email));
        expect(string, contains(testUser.role.toString()));
      });
    });
  });

  group('UserRole', () {
    group('fromString', () {
      test('should parse valid role strings', () {
        expect(UserRole.fromString('admin'), equals(UserRole.admin));
        expect(UserRole.fromString('moderator'), equals(UserRole.moderator));
        expect(UserRole.fromString('user'), equals(UserRole.user));
        expect(UserRole.fromString('guest'), equals(UserRole.guest));
      });

      test('should default to user for invalid strings', () {
        expect(UserRole.fromString('invalid'), equals(UserRole.user));
        expect(UserRole.fromString(''), equals(UserRole.user));
      });

      test('should be case insensitive', () {
        expect(UserRole.fromString('ADMIN'), equals(UserRole.admin));
        expect(UserRole.fromString('Moderator'), equals(UserRole.moderator));
      });
    });

    group('role checks', () {
      test('should correctly identify admin role', () {
        expect(UserRole.admin.isAdmin, isTrue);
        expect(UserRole.admin.isModerator, isTrue);
        expect(UserRole.admin.isUser, isTrue);
        expect(UserRole.admin.isGuest, isFalse);
      });

      test('should correctly identify moderator role', () {
        expect(UserRole.moderator.isAdmin, isFalse);
        expect(UserRole.moderator.isModerator, isTrue);
        expect(UserRole.moderator.isUser, isTrue);
        expect(UserRole.moderator.isGuest, isFalse);
      });

      test('should correctly identify user role', () {
        expect(UserRole.user.isAdmin, isFalse);
        expect(UserRole.user.isModerator, isFalse);
        expect(UserRole.user.isUser, isTrue);
        expect(UserRole.user.isGuest, isFalse);
      });

      test('should correctly identify guest role', () {
        expect(UserRole.guest.isAdmin, isFalse);
        expect(UserRole.guest.isModerator, isFalse);
        expect(UserRole.guest.isUser, isFalse);
        expect(UserRole.guest.isGuest, isTrue);
      });
    });
  });
}
