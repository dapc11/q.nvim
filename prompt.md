# q.nvim

This project is written by AI, and this document is used as input for the AI to set the context.

## Purpose

The purpose of this project is to build a Neovim plugin that integrates Amazon Q CLI, so that it could be used seamlessly when editing code and text with Neovim.

## Requirements

The tool shall be written in Lua and should be a standalone plugin base on [Neovim plugin best practises](file://./best_practises.md).
The plugin should mimic VS code core features:

### Inline chat
Seamlessly initiate chat within the inline coding experience. Select a section of code that you need assistance with and initiate chat within the editor to request actions such as "Optimize this code", "Add comments", or "Write tests".

### Chat
Generate code, explain code, and get answers about software development.

### Inline suggestions
Receive real-time code suggestions ranging from snippets to full functions based on your comments and existing code.

Support for at least languages: GoLang and Python.

