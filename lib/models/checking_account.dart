// Models a checking account with basic account details.
class CheckingAccount {
  // Name of the account (e.g., "Primary Checking").
  final String name;
  // Unique account number for identification.
  final String accountNumber;
  // Current balance in the account.
  final double balance;
  // Type of account (e.g., "Checking").
  final String type;
  // Name of the bank holding the account.
  final String bankName;

  // Constructor requiring all fields for complete account data.
  CheckingAccount({
    required this.name,
    required this.accountNumber,
    required this.balance,
    required this.type,
    required this.bankName,
  });
}