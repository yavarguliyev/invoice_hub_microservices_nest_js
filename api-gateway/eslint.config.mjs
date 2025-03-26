import path from 'path';
import eslint from '@eslint/js';
import eslintPluginPrettierRecommended from 'eslint-plugin-prettier/recommended';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  eslintPluginPrettierRecommended,
  {
    ignores: ['eslint.config.mjs'],
  },
  {
    languageOptions: {
      globals: { ...globals.node, ...globals.jest },
      ecmaVersion: 5,
      sourceType: 'module',
      parserOptions: {
        projectService: true,
        tsconfigRootDir: path.dirname(new URL(import.meta.url).pathname),
      },
    },
  },
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-floating-promises': 'warn',
      '@typescript-eslint/no-unsafe-argument': 'warn',
      'indent': 'off',
      'no-console': 0,
      'no-useless-constructor': 0,
      'no-dupe-class-members': 0,
      'no-unused-vars': 0,
      '@typescript-eslint/no-unused-vars': 1,
      'no-use-before-define': 'off',
      '@typescript-eslint/no-require-imports': 2,
      'no-redeclare': 0,
      '@typescript-eslint/no-redeclare': 2,
      'semi': ['error', 'always'],
      'space-before-function-paren': ['error', { anonymous: 'always', named: 'always', asyncArrow: 'always' }],
      "prettier/prettier": "off"
    }
  }
);
