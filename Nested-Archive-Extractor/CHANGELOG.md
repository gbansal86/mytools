# Changelog

## v3

- Added shorter temporary working paths to reduce Windows path-length failures.
- Improved handling of single-file compression wrappers such as ZST/GZ/XZ/BZ2.
- When a wrapper contains one inner archive, the program can continue directly into that archive instead of creating an unnecessary duplicate folder level.
- Separated fully successful outer archives from partially successful ones.
- Preserves recovery workspace after failed/partial nested extraction.
- Added more detailed logging for path and extraction failures.
- Kept original source archives untouched.

## v2

- Added ZST/Zstandard input support.
- Added recursive archive processing.
- Added extensionless archive detection.
- Added live GUI results and TXT report logging.

## v1

- Initial Windows Forms GUI.
- Multi-file/folder selection.
- Basic ZIP/7Z/RAR recursive extraction.
