<template>
  <div class="pf-table-sortable" :class="{ 'hover': hover, 'striped': striped }" @mouseleave="onMouseLeave()">

    <!-- head -->
    <b-row class="pf-table-sortable-head" @mouseenter="onMouseLeave()" @mousemove="onMouseLeave()">
      <b-col cols="1">
        <icon name="sort" class="text-secondary"></icon>
      </b-col>
      <b-col v-for="(field, fieldIndex) in visibleFields" :key="fieldIndex">
        {{ $t(field.label) }}
      </b-col>
    </b-row>
    <b-row v-if="items.length === 0"
      class="pf-table-sortable-empty justify-content-md-center"
    >
      <b-col cols="12" md="auto">
        <slot name="empty" v-bind="{ isLoading }">
          <pf-empty-table :isLoading="isLoading">{{ $t('No results found') }}</pf-empty-table>
        </slot>
      </b-col>
    </b-row>

    <!-- body -->
    <template v-else>
      <b-row v-for="(item, itemIndex) in notSortableItems" :key="itemIndex"
        class="pf-table-sortable-row"
        @mouseenter="onMouseLeave()"
      >
        <b-col cols="1">
          {{ itemIndex + 1 }}
        </b-col>
        <b-col v-for="(field, fieldIndex) in visibleFields" :key="fieldIndex" @click.stop="clickRow(item)">
          <slot :name="cell(field.key)" v-bind="{ item }">{{ item[field.key] }}</slot>
        </b-col>
      </b-row>
      <draggable
        v-model="sortableItems"
        :options="{ handle: '.draghandle', dragClass: 'dragclass' }"
        @start="onDraggable('start', $event)"
        @add="onDraggable('add', $event)"
        @remove="onDraggable('remove', $event)"
        @update="onDraggable('update', $event)"
        @end="onDraggable('end', $event)"
        @choose="onDraggable('choose', $event)"
        @sort="onDraggable('sort', $event)"
        @filter="onDraggable('filter', $event)"
        @clone="onDraggable('clone', $event)"
      >
        <b-row v-for="(item, itemIndex) in sortableItems" :key="itemIndex"
          class="pf-table-sortable-row"
          @mouseenter="onMouseEnter(itemIndex)"
          @mousemove="onMouseEnter(itemIndex)"
        >
          <b-col :class="{ 'draghandle': (sortableItems.length > 1) }" cols="1">
            <template v-if="!disabled && hoverIndex === itemIndex && sortableItems.length > 1">
              <icon name="th" v-b-tooltip.hover.left.d300 :title="$t('Click and drag to re-order')"></icon>
            </template>
            <template v-else>
              {{ notSortableItems.length + itemIndex + 1 }}
            </template>
          </b-col>
          <b-col v-for="(field, fieldIndex) in visibleFields" :key="fieldIndex" @click.stop="clickRow(item)">
            <slot :name="cell(field.key)" v-bind="{ item }">{{ item[field.key] }}</slot>
          </b-col>
        </b-row>
      </draggable>
    </template>

  </div>
</template>

<script>
import draggable from 'vuedraggable'
import pfEmptyTable from '@/components/pfEmptyTable'

export default {
  name: 'pf-table-sortable',
  components: {
    draggable,
    pfEmptyTable
  },
  props: {
    items: {
      type: Array,
      default: () => { return null },
      required: false
    },
    fields: {
      type: Array,
      default: () => { return [] },
      required: true
    },
    hover: {
      type: Boolean,
      default: false
    },
    striped: {
      type: Boolean,
      default: false
    },
    isLoading: {
      type: Boolean,
      default: false
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      hoverIndex: null, // row index onmouseover
      drag: false // true ondrag
    }
  },
  computed: {
    visibleFields () {
      return this.fields.filter(field => field.locked || field.visible)
    },
    sortableItems () {
      return this.items.filter(item => !item.not_sortable)
    },
    notSortableItems () {
      return this.items.filter(item => item.not_sortable)
    }
  },
  methods: {
    cell (name) {
      return `cell(${name})`
    },
    clickRow (item) {
      this.$emit('row-clicked', item)
    },
    onMouseEnter (index) {
      if (this.drag) return
      this.hoverIndex = index
    },
    onMouseLeave () {
      this.hoverIndex = null
    },
    onDraggable (type, event) {
      switch (type) {
        case 'start':
          this.drag = true
          break
        case 'end':
          this.drag = false
          break
      }
      this.$emit(type, event)
    }
  }
}
</script>

<style lang="scss">
.pf-table-sortable {
  color: #495057;
  border-spacing: 2px;
  .draghandle {
    cursor: grab;
    line-height: 1em;
  }
  .dragclass {
    padding-top: .25rem !important;
    padding-bottom: .0625rem !important;
    background-color: $primary !important;
    path, /* svg icons */
    * {
      color: $white !important;
      border-color: transparent !important;
    }
    button.btn {
      border: 1px solid $white !important;
      border-color: $white !important;
      color: $white !important;
    }
    input,
    select,
    .multiselect__single {
      color: $primary !important;
    }
    .pf-form-fields-input-group {
      border-color: transparent !important;
    }
  }
  .pf-table-sortable-empty {
    background-color: rgba(0,0,0,.05);
    vertical-align: top;
  }
  .pf-table-sortable-head {
    border-top: 1px solid #dee2e6;
    border-bottom: 2px solid #dee2e6;
    font-weight: bold;
    vertical-align: middle;
    & > div {
      vertical-align: bottom;
    }
  }
  .pf-table-sortable-row {
    border-top: 1px solid #dee2e6;
    cursor: pointer;
  }
  .pf-table-sortable-empty,
  .pf-table-sortable-head,
  .pf-table-sortable-row {
    border-color: #dee2e6;
    margin: 0;
    & > .col {
      align-self: center!important;
      padding: .75rem;
    }
    & > .col-1 {
      align-self: center!important;
      max-width: 50px;
      padding: .75rem;
      vertical-align: middle;
    }
  }
  &.striped {
    .pf-table-sortable-row {
      &:nth-of-type(odd) {
        background-color: rgba(0,0,0,.05);
      }
    }
  }
  &.hover {
    .pf-table-sortable-row {
      &:hover {
        background-color: rgba(0,0,0,.075);
        color: #495057;
      }
    }
  }
}
</style>
