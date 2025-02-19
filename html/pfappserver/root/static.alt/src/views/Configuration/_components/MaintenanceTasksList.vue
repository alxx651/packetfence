<template>
  <pf-config-list
    ref="pfConfigList"
    :config="config"
  >
    <template v-slot:pageHeader>
      <b-card-header>
        <h4 class="mb-3" v-t="'Maintenance Tasks'"></h4>
        <p class="mb-0" v-t="'Enabling or disabling a task as well as modifying its interval requires a restart of pfmon to be fully effective.'"></p>
      </b-card-header>
    </template>
    <template v-slot:buttonAdd>
      <pf-button-service service="pfmon" class="mr-1" restart start stop :disabled="isLoading"></pf-button-service>
    </template>
    <template v-slot:emptySearch="state">
      <pf-empty-table :isLoading="state.isLoading">{{ $t('No maintenance tasks found') }}</pf-empty-table>
    </template>
    <template v-slot:cell(status)="data">
      <pf-form-range-toggle
        v-model="data.status"
        :values="{ checked: 'enabled', unchecked: 'disabled' }"
        :icons="{ checked: 'check', unchecked: 'times' }"
        :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
        :disabled="isLoading"
        @input="toggleStatus(data, $event)"
        @click.stop.prevent
      >{{ (data.status === 'enabled') ? $t('Enabled') : $t('Disabled') }}</pf-form-range-toggle>
    </template>
    <template v-slot:cell(interval)="item">
      {{ item.interval.interval }}{{ item.interval.unit }}
    </template>
  </pf-config-list>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonService from '@/components/pfButtonService'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationMaintenanceTasksListConfig as config
} from '@/globals/configuration/pfConfigurationMaintenanceTasks'

export default {
  name: 'maintenance-tasks-list',
  components: {
    pfButtonDelete,
    pfButtonService,
    pfConfigList,
    pfEmptyTable,
    pfFormRangeToggle
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      config: config(this)
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    }
  },
  methods: {
    toggleStatus (item, newStatus) {
      switch (newStatus) {
        case 'enabled':
          this.$store.dispatch(`${this.storeName}/enableMaintenanceTask`, item)
          break
        case 'disabled':
          this.$store.dispatch(`${this.storeName}/disableMaintenanceTask`, item)
          break
      }
    }
  }
}
</script>
