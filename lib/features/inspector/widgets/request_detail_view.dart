import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/inspector/models/http_event_group.dart';
import 'package:soliplex_frontend/features/inspector/widgets/http_status_display.dart';
import 'package:soliplex_frontend/shared/utils/format_utils.dart';

/// Displays detailed request/response information in a tabbed view.
///
/// Tabs:
/// - Request: Method, URL, headers, body
/// - Response: Status, headers, body
/// - curl: Generated curl command for reproduction
class RequestDetailView extends StatelessWidget {
  const RequestDetailView({required this.group, super.key});

  final HttpEventGroup group;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          _buildSummaryHeader(context),
          const TabBar(
            tabs: [
              Tab(text: 'Request'),
              Tab(text: 'Response'),
              Tab(text: 'curl'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RequestTab(group: group),
                _ResponseTab(group: group),
                _CurlTab(group: group),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(SoliplexSpacing.s4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MethodBadge(
                method: group.methodLabel,
                isStream: group.isStream,
              ),
              const SizedBox(width: SoliplexSpacing.s2),
              Expanded(child: HttpStatusDisplay(group: group)),
              Text(
                group.timestamp.toHttpTimeString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: SoliplexSpacing.s2),
          SelectableText(
            group.uri.toString(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method, required this.isStream});

  final String method;
  final bool isStream;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isStream
        ? colorScheme.secondaryContainer
        : colorScheme.primaryContainer;
    final textColor = isStream
        ? colorScheme.onSecondaryContainer
        : colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SoliplexSpacing.s2,
        vertical: SoliplexSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: textColor,
        ),
      ),
    );
  }
}

class _RequestTab extends StatelessWidget {
  const _RequestTab({required this.group});

  final HttpEventGroup group;

  @override
  Widget build(BuildContext context) {
    // Use unified accessors that work for both regular requests and SSE
    final headers = group.requestHeaders;
    final body = group.requestBody;

    if (headers.isEmpty && body == null) {
      return const _EmptyTabContent(message: 'No request headers or body');
    }

    return ListView(
      padding: const EdgeInsets.all(SoliplexSpacing.s4),
      children: [
        if (headers.isNotEmpty) ...[
          _SectionHeader(
            title: 'Headers',
            onCopy: () => _copyHeaders(context, headers),
          ),
          _HeadersTable(headers: headers),
          const SizedBox(height: SoliplexSpacing.s4),
        ],
        if (body != null) ...[
          _SectionHeader(
            title: 'Body',
            onCopy: () => _copyBody(context, body),
          ),
          _BodyDisplay(body: body),
        ],
      ],
    );
  }

  void _copyHeaders(BuildContext context, Map<String, String> headers) {
    final text = headers.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    _copyToClipboard(context, text, 'Headers copied');
  }

  void _copyBody(BuildContext context, dynamic body) {
    final text = HttpEventGroup.formatBody(body);
    _copyToClipboard(context, text, 'Body copied');
  }
}

class _ResponseTab extends StatelessWidget {
  const _ResponseTab({required this.group});

  final HttpEventGroup group;

  @override
  Widget build(BuildContext context) {
    // For streams, show stream end data
    if (group.isStream) {
      return _buildStreamResponse(context);
    }

    final response = group.response;
    final error = group.error;

    if (response == null && error == null) {
      return const _EmptyTabContent(message: 'Waiting for response...');
    }

    if (error != null) {
      return _buildErrorResponse(context, error);
    }

    return _buildNormalResponse(context, response!);
  }

  Widget _buildStreamResponse(BuildContext context) {
    final streamEnd = group.streamEnd;
    if (streamEnd == null) {
      return const _EmptyTabContent(message: 'Stream in progress...');
    }

    if (streamEnd.error != null) {
      return _ErrorDisplay(
        message: streamEnd.error!.message,
        details: 'Duration: ${streamEnd.duration.toHttpDurationString()}\n'
            'Bytes received: ${streamEnd.bytesReceived.toHttpBytesString()}',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(SoliplexSpacing.s4),
      children: [
        _MetadataRow(
          label: 'Duration',
          value: streamEnd.duration.toHttpDurationString(),
        ),
        _MetadataRow(
          label: 'Bytes Received',
          value: streamEnd.bytesReceived.toHttpBytesString(),
        ),
        if (streamEnd.body != null) ...[
          const SizedBox(height: SoliplexSpacing.s4),
          _SectionHeader(
            title: 'Stream Content',
            onCopy: () => _copyToClipboard(
              context,
              streamEnd.body!,
              'Stream content copied',
            ),
          ),
          _BodyDisplay(body: streamEnd.body),
        ],
      ],
    );
  }

  Widget _buildErrorResponse(
    BuildContext context,
    HttpErrorEvent error,
  ) {
    return _ErrorDisplay(
      message: error.exception.message,
      details: 'Type: ${error.exception.runtimeType}\n'
          'Duration: ${error.duration.toHttpDurationString()}',
    );
  }

  Widget _buildNormalResponse(BuildContext context, HttpResponseEvent resp) {
    return ListView(
      padding: const EdgeInsets.all(SoliplexSpacing.s4),
      children: [
        _MetadataRow(label: 'Status', value: '${resp.statusCode}'),
        if (resp.reasonPhrase != null)
          _MetadataRow(label: 'Reason', value: resp.reasonPhrase!),
        _MetadataRow(
          label: 'Duration',
          value: resp.duration.toHttpDurationString(),
        ),
        _MetadataRow(
          label: 'Size',
          value: resp.bodySize.toHttpBytesString(),
        ),
        if (resp.headers != null && resp.headers!.isNotEmpty) ...[
          const SizedBox(height: SoliplexSpacing.s4),
          _SectionHeader(
            title: 'Headers',
            onCopy: () => _copyHeaders(context, resp.headers!),
          ),
          _HeadersTable(headers: resp.headers!),
        ],
        if (resp.body != null) ...[
          const SizedBox(height: SoliplexSpacing.s4),
          _SectionHeader(
            title: 'Body',
            onCopy: () => _copyBody(context, resp.body),
          ),
          _BodyDisplay(body: resp.body),
        ],
      ],
    );
  }

  void _copyHeaders(BuildContext context, Map<String, String> headers) {
    final text = headers.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    _copyToClipboard(context, text, 'Headers copied');
  }

  void _copyBody(BuildContext context, dynamic body) {
    final text = HttpEventGroup.formatBody(body);
    _copyToClipboard(context, text, 'Body copied');
  }
}

class _CurlTab extends StatelessWidget {
  const _CurlTab({required this.group});

  final HttpEventGroup group;

  @override
  Widget build(BuildContext context) {
    final curl = group.toCurl();
    if (curl == null) {
      return const _EmptyTabContent(
        message: 'curl command unavailable - no request data',
      );
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(SoliplexSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'curl command',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () => _copyToClipboard(
                  context,
                  curl,
                  'curl command copied',
                ),
                tooltip: 'Copy to clipboard',
              ),
            ],
          ),
          const SizedBox(height: SoliplexSpacing.s2),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SoliplexSpacing.s3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                curl,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onCopy});

  final String title;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SoliplexSpacing.s2),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const Spacer(),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: onCopy,
              tooltip: 'Copy $title',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _HeadersTable extends StatelessWidget {
  const _HeadersTable({required this.headers});

  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          for (final (index, entry) in headers.entries.indexed)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SoliplexSpacing.s3,
                vertical: SoliplexSpacing.s2,
              ),
              decoration: BoxDecoration(
                color: index.isEven
                    ? colorScheme.surfaceContainerLow
                    : colorScheme.surface,
                border: index > 0
                    ? Border(
                        top: BorderSide(color: colorScheme.outlineVariant),
                      )
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: SelectableText(
                      entry.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: SoliplexSpacing.s2),
                  Expanded(
                    child: SelectableText(
                      entry.value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
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

class _BodyDisplay extends StatelessWidget {
  const _BodyDisplay({required this.body});

  final dynamic body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedBody = HttpEventGroup.formatBody(body);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SoliplexSpacing.s3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: SelectableText(
        formattedBody,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SoliplexSpacing.s1),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTabContent extends StatelessWidget {
  const _EmptyTabContent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ErrorDisplay extends StatelessWidget {
  const _ErrorDisplay({required this.message, this.details});

  final String message;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(SoliplexSpacing.s4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: SoliplexSpacing.s3),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          if (details != null) ...[
            const SizedBox(height: SoliplexSpacing.s2),
            Text(
              details!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

void _copyToClipboard(BuildContext context, String text, String message) {
  Clipboard.setData(ClipboardData(text: text)).then((_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  });
}
