<script>
  import { TriiiceratopsViewer } from 'triiiceratops';
  import 'triiiceratops/style.css';
  let viewerState = $state();
  let {manifestId, initialId, live, ...allProps} = $props()
  let canvasId = $state(initialId)

  $effect(() => {
    if (viewerState?.canvasId && viewerState.canvasId !== canvasId) {
      canvasId = viewerState.canvasId;
    }
  })
</script>

<div class="absolute w-full h-full">
  <TriiiceratopsViewer bind:viewerState {canvasId} {manifestId} {...allProps} />
</div>
