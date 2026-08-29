package com.example.ai_agent

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Reads the current screen's accessibility tree into a flat list of nodes,
 * and executes single actions (tap, text input, scroll, back) requested by
 * the AI layer. This service only ever acts on THIS device, driven by the
 * app's own UI — there is no remote/background control channel here.
 */
class AgentAccessibilityService : AccessibilityService() {

    companion object {
        var instance: AgentAccessibilityService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    /** Flattens the current window's node tree into simple maps for Dart. */
    fun captureScreen(): List<Map<String, Any?>> {
        val root = rootInActiveWindow ?: return emptyList()
        val results = mutableListOf<Map<String, Any?>>()
        collect(root, results)
        return results
    }

    private fun collect(node: AccessibilityNodeInfo, out: MutableList<Map<String, Any?>>) {
        if (out.size > 200) return // safety cap on huge trees
        val bounds = Rect()
        node.getBoundsInScreen(bounds)

        val isInteresting = node.isClickable || node.isEditable || node.isScrollable ||
            !node.text.isNullOrEmpty() || !node.contentDescription.isNullOrEmpty()

        if (isInteresting) {
            out.add(
                mapOf(
                    "text" to node.text?.toString(),
                    "contentDescription" to node.contentDescription?.toString(),
                    "className" to (node.className?.toString() ?: ""),
                    "clickable" to node.isClickable,
                    "editable" to node.isEditable,
                    "scrollable" to node.isScrollable,
                    "bounds" to listOf(bounds.left, bounds.top, bounds.right, bounds.bottom),
                )
            )
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collect(child, out)
            child.recycle()
        }
    }

    fun performTap(x: Int, y: Int) {
        val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 80))
            .build()
        dispatchGesture(gesture, null, null)
    }

    fun performScroll(direction: String) {
        val displayMetrics = resources.displayMetrics
        val midX = displayMetrics.widthPixels / 2f
        val startY = displayMetrics.heightPixels * 0.7f
        val endY = displayMetrics.heightPixels * 0.3f
        val path = Path().apply {
            when (direction) {
                "up" -> { moveTo(midX, endY); lineTo(midX, startY) }
                "down" -> { moveTo(midX, startY); lineTo(midX, endY) }
                else -> { moveTo(midX, startY); lineTo(midX, endY) }
            }
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
            .build()
        dispatchGesture(gesture, null, null)
    }

    fun performInputText(text: String) {
        val root = rootInActiveWindow ?: return
        val focused = findFocusedEditable(root) ?: return
        val args = Bundle()
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun performBack() {
        performGlobalAction(GLOBAL_ACTION_BACK)
    }

    private fun findFocusedEditable(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable && node.isFocused) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findFocusedEditable(child)
            if (found != null) return found
            child.recycle()
        }
        return null
    }
}
