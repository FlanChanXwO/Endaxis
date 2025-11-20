<script setup>
import { computed, ref } from 'vue'
import { useTimelineStore } from '../stores/timelineStore.js'
import draggable from 'vuedraggable'

const store = useTimelineStore()

// 中文映射
const EFFECT_NAMES = {
  "break": "破防", "armor_break": "碎甲", "stagger": "猛击", "knockdown": "倒地", "knockup": "击飞",
  "blaze_attach": "灼热附着", "emag_attach": "电磁附着", "cold_attach": "寒冷附着", "nature_attach": "自然附着",
  "blaze_burst": "灼热爆发", "emag_burst": "电磁爆发", "cold_burst": "寒冷爆发", "nature_burst": "自然爆发",
  "burning": "燃烧", "conductive": "导电", "frozen": "冻结", "ice_shatter": "碎冰", "corrosion": "腐蚀",
  "default": "默认图标"
}

// === 库模式逻辑 ===
const selectedLibrarySkill = computed(() => {
  if (!store.selectedLibrarySkillId) return null
  return store.activeSkillLibrary.find(s => s.id === store.selectedLibrarySkillId)
})

function updateLibraryProp(key, value) {
  if (!selectedLibrarySkill.value) return
  store.updateLibrarySkill(selectedLibrarySkill.value.id, { [key]: value })
}

// === 动作模式逻辑 ===
const selectedAction = computed(() => {
  if (!store.selectedActionId) return null
  for (const track of store.tracks) {
    const found = track.actions.find(a => a.instanceId === store.selectedActionId)
    if (found) return found
  }
  return null
})

// 获取当前动作所属的干员
const currentCharacter = computed(() => {
  if (!selectedAction.value) return null;
  const track = store.tracks.find(t => t.actions.some(a => a.instanceId === store.selectedActionId));
  if (!track) return null;
  return store.characterRoster.find(c => c.id === track.id);
})

const editingEffectIndex = ref(null)

const iconOptions = computed(() => {
  const allGlobalKeys = Object.keys(store.iconDatabase);
  const allowed = selectedAction.value?.allowedTypes;

  const filteredGlobalKeys = (allowed && allowed.length > 0)
      ? allGlobalKeys.filter(key => allowed.includes(key) || key === 'default')
      : allGlobalKeys;

  const globalOptions = filteredGlobalKeys.map(key => ({
    label: EFFECT_NAMES[key] || key,
    value: key,
    path: store.iconDatabase[key]
  }));

  let exclusiveOptions = [];
  if (currentCharacter.value && currentCharacter.value.exclusive_buffs) {
    exclusiveOptions = currentCharacter.value.exclusive_buffs.map(buff => ({
      label: `★ ${buff.name}`,
      value: buff.key,
      path: buff.path
    }));
    if (allowed && allowed.length > 0) {
      exclusiveOptions = exclusiveOptions.filter(opt => allowed.includes(opt.value));
    }
  }
  return [...exclusiveOptions, ...globalOptions];
})

const relevantConnections = computed(() => {
  if (!store.selectedActionId) return []
  return store.connections.filter(c =>
      c.from === store.selectedActionId || c.to === store.selectedActionId
  ).map(conn => {
    const isOutgoing = conn.from === store.selectedActionId
    const otherActionId = isOutgoing ? conn.to : conn.from
    let otherActionName = '未知动作';
    for (const track of store.tracks) {
      const action = track.actions.find(a => a.instanceId === otherActionId)
      if (action) { otherActionName = action.name; break; }
    }
    return { id: conn.id, direction: isOutgoing ? '连向' : '来自', otherActionName, isOutgoing }
  })
})

function getIconPath(type) {
  if (currentCharacter.value && currentCharacter.value.exclusive_buffs) {
    const exclusive = currentCharacter.value.exclusive_buffs.find(b => b.key === type);
    if (exclusive && exclusive.path) {
      return exclusive.path;
    }
  }
  return store.iconDatabase[type] || store.iconDatabase['default'] || ''
}

function updateActionProp(key, value) {
  if (!selectedAction.value) return;
  store.updateAction(store.selectedActionId, { [key]: value });
}

function updateAnomaliesList(newList) {
  if (!selectedAction.value) return
  store.updateAction(store.selectedActionId, { physicalAnomaly: newList })
}

function updateEffectProp(index, key, value) {
  if (!selectedAction.value) return
  const list = [...selectedAction.value.physicalAnomaly]
  list[index][key] = value
  store.updateAction(store.selectedActionId, { physicalAnomaly: list })
}

function addEffect() {
  if (!selectedAction.value) return
  const list = [...(selectedAction.value.physicalAnomaly || [])]
  list.push({ type: 'default', stacks: 1, duration: 0 })
  store.updateAction(store.selectedActionId, { physicalAnomaly: list })
  editingEffectIndex.value = list.length - 1
}

function removeEffect(index) {
  if (!selectedAction.value) return
  const list = [...selectedAction.value.physicalAnomaly]
  list.splice(index, 1)
  store.updateAction(store.selectedActionId, { physicalAnomaly: list })
  if (editingEffectIndex.value === index) { editingEffectIndex.value = null }
  else if (editingEffectIndex.value > index) { editingEffectIndex.value-- }
}

const anomalyList = computed({
  get: () => selectedAction.value?.physicalAnomaly || [],
  set: (val) => updateAnomaliesList(val)
})
</script>

<template>
  <div v-if="selectedAction" class="properties-panel">
    <h3 class="panel-title">动作实例编辑</h3>

    <button class="link-btn" @click="store.startLinking()" :class="{ 'is-linking': store.isLinking && store.linkingEffectIndex === null }">
      {{ (store.isLinking && store.linkingEffectIndex === null) ? '请点击目标动作块...' : '🔗 建立连线' }}
    </button>

    <div class="attribute-editor">
      <div class="info-row"><label>名称</label><span class="action-name">{{ selectedAction.name }}</span></div>
      <div class="info-row"><label>冷却时间 (CD)</label><input type="number" :value="selectedAction.cooldown" @input="e => updateActionProp('cooldown', Number(e.target.value))" min="0"></div>
    </div>

    <div v-if="relevantConnections.length > 0" class="connections-list-area">
      <div class="info-row"><label>现有连线</label></div>
      <div v-for="conn in relevantConnections" :key="conn.id" class="connection-item" :class="{ 'is-outgoing': conn.isOutgoing, 'is-incoming': !conn.isOutgoing }">
        <span class="conn-icon">{{ conn.isOutgoing ? '➔' : '←' }}</span>
        <span class="conn-text">{{ conn.direction }} {{ conn.otherActionName }}</span>
        <div class="delete-conn-btn" @click="store.removeConnection(conn.id)" title="断开连线">×</div>
      </div>
    </div>

    <hr class="divider" />

    <div class="info-row" style="margin-bottom: 5px;">
      <label>状态效果 (可拖拽排序)</label>
      <div class="add-icon-btn" @click="addEffect" title="添加效果">+</div>
    </div>

    <div class="icon-stream-container">
      <draggable
          v-model="anomalyList"
          item-key="type"
          class="icon-list"
          :animation="200"
          ghost-class="ghost-icon"
      >
        <template #item="{ element, index }">
          <div
              class="icon-wrapper"
              :class="{ 'is-editing': editingEffectIndex === index }"
              @click="editingEffectIndex = index"
          >
            <img :src="getIconPath(element.type)" class="mini-icon" />
            <div v-if="element.stacks > 1" class="mini-stacks">{{ element.stacks }}</div>
          </div>
        </template>
      </draggable>
    </div>

    <div v-if="editingEffectIndex !== null && selectedAction.physicalAnomaly[editingEffectIndex]" class="effect-detail-editor">
      <div class="editor-header">
        <span>编辑效果 #{{ editingEffectIndex + 1 }}</span>
        <button class="close-btn" @click="editingEffectIndex = null">×</button>
      </div>

      <div class="form-row">
        <label>类型</label>
        <select :value="selectedAction.physicalAnomaly[editingEffectIndex].type" @change="e => updateEffectProp(editingEffectIndex, 'type', e.target.value)">
          <option v-for="opt in iconOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
        </select>
      </div>

      <div class="form-row">
        <label>层数 (Stacks)</label>
        <input type="number" :value="selectedAction.physicalAnomaly[editingEffectIndex].stacks" @input="e => updateEffectProp(editingEffectIndex, 'stacks', Number(e.target.value))" min="1">
      </div>

      <div class="form-row">
        <label>持续时间 (Duration)</label>
        <input type="number" :value="selectedAction.physicalAnomaly[editingEffectIndex].duration" @input="e => updateEffectProp(editingEffectIndex, 'duration', Number(e.target.value))" min="0" step="0.5">
      </div>

      <button class="effect-link-btn"
              @click="store.startLinking(editingEffectIndex)"
              :class="{ 'is-linking': store.isLinking && store.linkingEffectIndex === editingEffectIndex }">
        {{ (store.isLinking && store.linkingEffectIndex === editingEffectIndex) ? '请点击目标动作...' : '🔗 从此效果连线' }}
      </button>

      <button class="delete-btn" @click="removeEffect(editingEffectIndex)">删除此效果</button>
    </div>
  </div>

  <div v-else-if="selectedLibrarySkill" class="properties-panel library-mode">
    <h3 class="panel-title" style="color: #4a90e2;">基础数值调整</h3>
    <div class="panel-desc">
      修改当前干员 <strong>{{ selectedLibrarySkill.name }}</strong> 的基础属性。<br/>
      此修改仅对<strong>后续拖入</strong>的动作生效，且仅影响当前会话。
    </div>

    <div class="attribute-editor">
      <div class="info-row"><label>名称</label><span class="action-name">{{ selectedLibrarySkill.name }}</span></div>

      <div class="form-group">
        <label>持续时间 (Duration)</label>
        <input type="number" :value="selectedLibrarySkill.duration" @input="e => updateLibraryProp('duration', Number(e.target.value))" min="0.5" step="0.5">
      </div>

      <div class="form-group">
        <label>冷却时间 (Cooldown)</label>
        <input type="number" :value="selectedLibrarySkill.cooldown" @input="e => updateLibraryProp('cooldown', Number(e.target.value))" min="0">
      </div>

      <div class="form-group">
        <label>SP 消耗 (Cost)</label>
        <input type="number" :value="selectedLibrarySkill.spCost" @input="e => updateLibraryProp('spCost', Number(e.target.value))" min="0">
      </div>

      <div class="form-group">
        <label>SP 回复 (Gain)</label>
        <input type="number" :value="selectedLibrarySkill.spGain" @input="e => updateLibraryProp('spGain', Number(e.target.value))" min="0">
      </div>
    </div>

    <div class="info-box">
      <p>💡 提示：点击左侧相同技能块可取消选中。</p>
    </div>
  </div>

  <div v-else class="properties-panel empty">
    <p>请选中一个动作块或技能库图标</p>
  </div>
</template>

<style scoped>
.properties-panel { padding: 15px; color: #e0e0e0; background-color: #2b2b2b; height: 100%; box-sizing: border-box; overflow-y: auto; border-left: 1px solid #444; font-size: 14px; }
.attribute-editor { border: 1px solid #444; padding: 10px; border-radius: 6px; margin-bottom: 15px; }
.panel-title { color: #ffd700; margin-top: 0; margin-bottom: 15px; }
.info-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; color: #aaa; }
.action-name { color: #fff; font-weight: bold; }
.divider { border: 0; border-top: 1px solid #444; margin: 15px 0; }
.link-btn { width: 100%; padding: 8px; margin-bottom: 10px; background-color: #444; color: #ffd700; border: 1px solid #ffd700; border-radius: 4px; cursor: pointer; font-weight: bold; }
.link-btn:hover { background-color: #555; }
.link-btn.is-linking { background-color: #ffd700; color: #000; animation: pulse 1s infinite; }
.connections-list-area { margin-bottom: 20px; }
.connection-item { display: flex; justify-content: space-between; align-items: center; background-color: #3a3a3a; padding: 8px; border-radius: 4px; margin-bottom: 5px; border: 1px solid transparent; }
.connection-item.is-outgoing { border-left-color: #ffd700; }
.connection-item.is-incoming { border-left-color: #00e5ff; }
.conn-icon { font-size: 14px; margin-right: 5px; }
.conn-text { font-size: 13px; flex-grow: 1; }
.delete-conn-btn { background-color: #555; color: white; padding: 3px 8px; border-radius: 4px; font-size: 12px; margin-left: 10px; cursor: pointer; transition: background-color 0.2s; }
.delete-conn-btn:hover { background-color: #d32f2f; }
@keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.7; } 100% { opacity: 1; } }
.icon-stream-container { display: flex; flex-wrap: wrap; gap: 8px; background: #333; padding: 10px; border-radius: 6px; border: 1px solid #555; min-height: 50px; align-items: center; }
.icon-list { display: flex; flex-wrap: wrap; gap: 8px; }
.icon-wrapper { position: relative; width: 40px; height: 40px; background: #444; border: 1px solid #666; border-radius: 4px; display: flex; align-items: center; justify-content: center; cursor: pointer; transition: all 0.2s; }
.icon-wrapper:hover { border-color: #888; background: #555; }
.icon-wrapper.is-editing { border-color: #ffd700; background: #4a4a3a; }
.mini-icon { width: 28px; height: 28px; object-fit: contain; }
.mini-stacks { position: absolute; bottom: 0; right: 0; background: rgba(0,0,0,0.7); color: #fff; font-size: 10px; padding: 0 2px; border-radius: 2px; line-height: 1; }
.add-icon-btn { width: 40px; height: 40px; border: 1px dashed #777; border-radius: 4px; display: flex; align-items: center; justify-content: center; color: #777; font-size: 24px; cursor: pointer; line-height: 1;  padding-bottom: 3px; }
.add-icon-btn:hover { border-color: #4CAF50; color: #4CAF50; background: rgba(76, 175, 80, 0.1); }
.ghost-icon { opacity: 0.5; background: #ffd700; }
.effect-detail-editor { margin-top: 15px; background: #3a3a3a; padding: 12px; border-radius: 6px; border: 1px solid #555; animation: fadeIn 0.2s ease; }
.editor-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; color: #ffd700; font-size: 12px; }
.close-btn { background: none; border: none; color: #aaa; cursor: pointer; font-size: 16px; padding: 0; }
.close-btn:hover { color: #fff; }
.form-row { margin-bottom: 8px; }
.form-row label { display: block; margin-bottom: 4px; font-size: 12px; color: #bbb; }
select, input { width: 100%; box-sizing: border-box; background: #222; color: white; border: 1px solid #555; padding: 6px; border-radius: 4px; }
select:focus, input:focus { border-color: #ffd700; outline: none; }
.delete-btn { width: 100%; padding: 6px; margin-top: 10px; background-color: #d32f2f; color: white; border: none; border-radius: 4px; cursor: pointer; }
.delete-btn:hover { background-color: #b71c1c; }
.placeholder-text { margin-top: 20px; text-align: center; color: #666; font-style: italic; font-size: 12px; }
.empty { display: flex; align-items: center; justify-content: center; color: #666; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(-5px); } to { opacity: 1; transform: translateY(0); } }
.effect-link-btn { width: 100%; padding: 6px; margin-top: 10px; background-color: #444; color: #ffd700; border: 1px dashed #ffd700; border-radius: 4px; cursor: pointer; font-size: 12px; transition: all 0.2s; }
.effect-link-btn:hover { background-color: #555; }
.effect-link-btn.is-linking { background-color: #ffd700; color: #000; border-style: solid; animation: pulse 1s infinite; }
.panel-desc { font-size: 12px; color: #aaa; margin-bottom: 20px; line-height: 1.5; background: rgba(74, 144, 226, 0.1); padding: 8px; border-radius: 4px; border-left: 2px solid #4a90e2; }
.library-mode .attribute-editor { border-color: #4a90e2; }
.form-group { margin-bottom: 12px; }
.form-group label { display: block; margin-bottom: 4px; font-size: 12px; color: #bbb; }
.info-box { margin-top: 20px; font-size: 12px; color: #666; text-align: center; }
</style>